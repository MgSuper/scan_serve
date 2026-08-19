import { Firestore, Timestamp, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { ApplicationError } from '../shared/errors/application_error';
import type {
  SubmitOrderItem,
  SubmitOrderPayload,
} from '../validators/callable_request_validator';

interface CartItemRecord {
  menuItemId: string;
  quantity: number;
  note?: string;
  modifiers?: string[];
  unitPrice?: number;
}

interface OrderSummary {
  id: string;
  restaurantId: string;
  status: 'PENDING';
  subtotal: number;
  total: number;
  totalQuantity: number;
  submittedAt: string;
}

const requireRecord = (value: unknown, message: string): Record<string, unknown> => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new ApplicationError('VALIDATION_FAILED', message);
  }
  return value as Record<string, unknown>;
};

/** Executes CF-002 using one transaction for all mutable order state. */
export class OrderService {
  public constructor(private readonly firestore: Firestore) {}

  public async submitOrder(requestId: string, input: SubmitOrderPayload): Promise<OrderSummary> {
    const resolvedCustomerSessionId = this.resolveCustomerSessionId(
      input.customerSessionId,
    );
    const resolvedCartId =
      input.cartId?.trim() || this.canonicalCartId(resolvedCustomerSessionId);
    const resolvedInput = {
      ...input,
      customerSessionId: resolvedCustomerSessionId,
      cartId: resolvedCartId,
    };
    const items = resolvedInput.items;
    if (items?.length) {
      return this.submitInlineOrder(requestId, { ...resolvedInput, items });
    }
    return this.submitCartOrder(requestId, { ...resolvedInput, cartId: resolvedCartId });
  }

  private async submitCartOrder(
    requestId: string,
    input: SubmitOrderPayload & { cartId: string },
  ): Promise<OrderSummary> {
    const now = Timestamp.now();
    const result = await this.firestore.runTransaction(async (transaction) => {
      const sessionRef = this.customerSessionReference(input.customerSessionId);
      const cartReferences = this.cartReferences(
        input.customerSessionId,
        input.cartId,
      );
      const idempotencyRef = this.firestore.collection('orderRequests').doc(requestId);
      const [requestSnapshot, sessionSnapshot, ...cartSnapshots] = await Promise.all([
        transaction.get(idempotencyRef),
        transaction.get(sessionRef),
        ...cartReferences.map((reference) => transaction.get(reference)),
      ]);
      const existingCartIndex = cartSnapshots.findIndex((snapshot) => snapshot.exists);
      const cartRef =
        cartReferences[existingCartIndex >= 0 ? existingCartIndex : 0];
      const cartSnapshot =
        cartSnapshots[existingCartIndex >= 0 ? existingCartIndex : 0];

      if (requestSnapshot.exists) {
        const previous = requireRecord(requestSnapshot.data(), 'Stored request is invalid.');
        if (previous.restaurantId !== input.restaurantId) {
          throw new ApplicationError('UNAUTHORIZED', 'Request belongs to another restaurant.');
        }
        return previous.summary as OrderSummary;
      }
      let session: Record<string, unknown>;
      if (!sessionSnapshot.exists) {
        if (!this.isDevelopmentSessionFallbackEnabled()) {
          throw new ApplicationError('NOT_FOUND', 'Customer session was not found.');
        }
        session = this.createDevelopmentSession(input, now);
      } else {
        session = requireRecord(sessionSnapshot.data(), 'Customer session is invalid.');
      }
      if (
        session.restaurantId !== input.restaurantId ||
        session.status !== 'ACTIVE' ||
        session.isArchived === true ||
        session.deletedAt
      ) {
        throw new ApplicationError('UNAUTHORIZED', 'Customer session is not active for this restaurant.');
      }
      const expiresAt = session.expiresAt as Timestamp | undefined;
      if (expiresAt && expiresAt.toMillis() <= now.toMillis()) {
        throw new ApplicationError('VALIDATION_FAILED', 'Customer session has expired.');
      }

      if (!cartSnapshot.exists) {
        if (this.isDevelopmentSessionFallbackEnabled() && input.items?.length) {
          const lines = input.items.map((item) => ({
            menuItemId: item.menuItemId,
            quantity: item.quantity,
            ...(item.note === undefined ? {} : { note: item.note }),
            ...(item.modifiers === undefined ? {} : { modifiers: item.modifiers }),
          }));
          const sessionToCreate = sessionSnapshot.exists
            ? undefined
            : { ref: sessionRef, data: session };
          const cartToCreate = {
            ref: cartRef,
            data: this.createDevelopmentCart(
              { ...input, cartId: this.canonicalCartId(input.customerSessionId) },
              lines,
              now,
            ),
          };
          return this.createOrderInTransaction(
            transaction,
            requestId,
            input,
            session,
            lines,
            now,
            undefined,
            sessionToCreate,
            cartToCreate,
          );
        }
        if (this.isDevelopmentSessionFallbackEnabled()) {
          throw new ApplicationError(
            'VALIDATION_FAILED',
            'No cart or inline order items were provided.',
          );
        }
        throw new ApplicationError('NOT_FOUND', 'Cart was not found.');
      }
      const cart = requireRecord(cartSnapshot.data(), 'Cart is invalid.');
      if (
        cart.restaurantId !== input.restaurantId ||
        cart.customerSessionId !== input.customerSessionId ||
        cart.isArchived === true ||
        cart.deletedAt
      ) {
        throw new ApplicationError('UNAUTHORIZED', 'Cart does not belong to this customer session.');
      }
      const cartItems = cart.items;
      if (!Array.isArray(cartItems) || cartItems.length === 0) {
        throw new ApplicationError('VALIDATION_FAILED', 'Cart must contain at least one item.');
      }

      const lines = cartItems.map((item) => this.parseCartItem(item));
      const sessionToCreate = sessionSnapshot.exists
        ? undefined
        : { ref: sessionRef, data: session };
      return this.createOrderInTransaction(
        transaction,
        requestId,
        input,
        session,
        lines,
        now,
        cartRef,
        sessionToCreate,
      );
    });
    logger.info('submitOrder completed', {
      requestId,
      restaurantId: input.restaurantId,
      orderId: result.id,
    });
    return result;
  }

  private async submitInlineOrder(
    requestId: string,
    input: SubmitOrderPayload & { items: SubmitOrderItem[] },
  ): Promise<OrderSummary> {
    const now = Timestamp.now();
    const result = await this.firestore.runTransaction(async (transaction) => {
      const idempotencyRef = this.firestore.collection('orderRequests').doc(requestId);
      const sessionRef = this.customerSessionReference(input.customerSessionId);
      const cartReferences = this.cartReferences(
        input.customerSessionId,
        input.cartId,
      );
      const [requestSnapshot, sessionSnapshot, ...cartSnapshots] = await Promise.all([
        transaction.get(idempotencyRef),
        transaction.get(sessionRef),
        ...cartReferences.map((reference) => transaction.get(reference)),
      ]);
      const existingCartIndex = cartSnapshots.findIndex((snapshot) => snapshot.exists);
      const cartRef =
        cartReferences[existingCartIndex >= 0 ? existingCartIndex : 0];
      const cartSnapshot =
        cartSnapshots[existingCartIndex >= 0 ? existingCartIndex : 0];
      if (requestSnapshot.exists) {
        const previous = requireRecord(requestSnapshot.data(), 'Stored request is invalid.');
        if (previous.restaurantId !== input.restaurantId) {
          throw new ApplicationError('UNAUTHORIZED', 'Request belongs to another restaurant.');
        }
        return previous.summary as OrderSummary;
      }

      let session: Record<string, unknown>;
      if (!sessionSnapshot.exists) {
        if (!this.isDevelopmentSessionFallbackEnabled()) {
          throw new ApplicationError('NOT_FOUND', 'Customer session was not found.');
        }
        session = this.createDevelopmentSession(input, now);
      } else {
        session = requireRecord(sessionSnapshot.data(), 'Customer session is invalid.');
      }
      if (
        session.restaurantId !== input.restaurantId ||
        session.status !== 'ACTIVE' ||
        session.isArchived === true ||
        session.deletedAt
      ) {
        throw new ApplicationError('UNAUTHORIZED', 'Customer session is not active for this restaurant.');
      }
      const expiresAt = session.expiresAt as Timestamp | undefined;
      if (expiresAt && expiresAt.toMillis() <= now.toMillis()) {
        throw new ApplicationError('VALIDATION_FAILED', 'Customer session has expired.');
      }

      const lines = input.items.map((item) => ({
        menuItemId: item.menuItemId,
        quantity: item.quantity,
        ...(item.note === undefined ? {} : { note: item.note }),
        ...(item.modifiers === undefined ? {} : { modifiers: item.modifiers }),
      }));
      const sessionToCreate = sessionSnapshot.exists
        ? undefined
        : { ref: sessionRef, data: session };
      const cartToCreate = cartSnapshot.exists || !this.isDevelopmentSessionFallbackEnabled()
        ? undefined
        : {
            ref: cartRef,
            data: this.createDevelopmentCart(
              { ...input, cartId: this.canonicalCartId(input.customerSessionId) },
              lines,
              now,
            ),
          };
      return this.createOrderInTransaction(
        transaction,
        requestId,
        input,
        session,
        lines,
        now,
        cartSnapshot.exists ? cartRef : undefined,
        sessionToCreate,
        cartToCreate,
      );
    });
    logger.info('submitOrder completed', {
      requestId,
      restaurantId: input.restaurantId,
      orderId: result.id,
    });
    return result;
  }

  private async createOrderInTransaction(
    transaction: Transaction,
    requestId: string,
    input: SubmitOrderPayload,
    session: Record<string, unknown>,
    lines: CartItemRecord[],
    now: Timestamp,
    cartRef?: FirebaseFirestore.DocumentReference,
    sessionToCreate?: {
      ref: FirebaseFirestore.DocumentReference;
      data: Record<string, unknown>;
    },
    cartToCreate?: {
      ref: FirebaseFirestore.DocumentReference;
      data: Record<string, unknown>;
    },
  ): Promise<OrderSummary> {
    const developmentFallbackEnabled = this.isDevelopmentSessionFallbackEnabled();
    const sessionBranchId =
      typeof session.branchId === 'string' && session.branchId.trim().length > 0
        ? session.branchId
        : 'main-branch';
    const restaurantRef = this.firestore.collection('restaurants').doc(input.restaurantId);
    const branchRef = restaurantRef.collection('branches').doc(sessionBranchId);
    const menuRefs = lines.map((line) =>
      this.firestore
        .collection('restaurants')
        .doc(input.restaurantId)
        .collection('menu')
        .doc(line.menuItemId),
    );
    const [restaurantSnapshot, branchSnapshot, ...menuSnapshots] = await Promise.all([
      transaction.get(restaurantRef),
      transaction.get(branchRef),
      ...menuRefs.map(async (nested) => ({
        nestedSnapshot: await transaction.get(nested),
        nested,
      })),
    ]);
    const orderId = this.firestore.collection('orders').doc().id;
    const orderItems: Array<{
      ref: FirebaseFirestore.DocumentReference;
      data: Record<string, unknown>;
      nested: Record<string, unknown>;
    }> = [];
    const menuToCreate: Array<{
      ref: FirebaseFirestore.DocumentReference;
      data: Record<string, unknown>;
    }> = [];
    logger.info('Order menu resolution started', {
      requestId,
      restaurantId: input.restaurantId,
      branchId: session.branchId,
      menuItemIds: lines.map((line) => line.menuItemId),
      nestedMenuPaths: menuRefs.map((reference) => reference.path),
      developmentFallbackEnabled,
    });

    for (let index = 0; index < menuSnapshots.length; index += 1) {
      const { nestedSnapshot, nested } = menuSnapshots[index];
      // The nested restaurant menu is the canonical source used by Flutter
      // and Angular. Legacy top-level menu records are intentionally ignored
      // so stale data cannot reject a valid restaurant-scoped item.
      const snapshot = nestedSnapshot;
      const line = lines[index];
      logger.info('Order menu item snapshot', {
        requestId,
        menuItemId: line.menuItemId,
        nestedPath: nested.path,
        nestedExists: nestedSnapshot.exists,
        selectedPath: snapshot.exists ? snapshot.ref.path : nested.path,
      });
      let menu: Record<string, unknown>;
      let menuItemId: string;
      if (!snapshot.exists) {
        if (!developmentFallbackEnabled) {
          throw new ApplicationError('NOT_FOUND', 'A menu item is no longer available.');
        }
        menuItemId = line.menuItemId;
        menu = this.createDevelopmentMenuItem(input, session, line, now);
        menuToCreate.push({ ref: nested, data: menu });
      } else {
        menuItemId = snapshot.id;
        menu = requireRecord(snapshot.data(), 'Menu item is invalid.');
      }

      const restaurantMatches =
        typeof menu.restaurantId !== 'string'
          ? developmentFallbackEnabled
          : menu.restaurantId === input.restaurantId;
      const branchMatches =
        typeof menu.branchId !== 'string'
          ? true
          : menu.branchId === sessionBranchId;
      const availabilityValid =
        menu.isAvailable === true ||
        menu.status === 'in_stock' ||
        menu.availability === 'in_stock' ||
        (developmentFallbackEnabled && menu.isAvailable === undefined);
      if (
        !restaurantMatches ||
        !branchMatches ||
        !availabilityValid ||
        menu.isArchived === true ||
        menu.deletedAt
      ) {
        logger.warn('Order menu item rejected', {
          requestId,
          menuItemId,
          restaurantMatches,
          branchMatches,
          availabilityValid,
          restaurantId: menu.restaurantId,
          menuBranchId: menu.branchId ?? sessionBranchId,
          isAvailable: menu.isAvailable,
          availability: menu.availability,
          status: menu.status,
          isArchived: menu.isArchived,
          deletedAt: menu.deletedAt,
        });
        throw new ApplicationError('VALIDATION_FAILED', 'A menu item is unavailable.');
      }
      const rawPrice = menu.price;
      const unitPrice =
        Number.isSafeInteger(rawPrice) && (rawPrice as number) >= 0
          ? (rawPrice as number)
          : developmentFallbackEnabled
            ? 1000
            : undefined;
      if (unitPrice === undefined) {
        throw new ApplicationError('INTERNAL_ERROR', 'Menu item price is invalid.');
      }
      const orderItemRef = this.firestore.collection('orderItems').doc();
      const lineTotal = unitPrice * line.quantity;
      const nestedItem = {
        itemId: menuItemId,
        menuItemId,
        name: typeof menu.name === 'string' ? menu.name : menuItemId,
        category: typeof menu.category === 'string' ? menu.category : 'Menu',
        unitPrice,
        price: unitPrice,
        quantity: line.quantity,
        lineTotal,
      };
      orderItems.push({
        ref: orderItemRef,
        data: {
          id: orderItemRef.id,
          orderId,
          restaurantId: input.restaurantId,
          branchId: session.branchId,
          menuItemId,
          categoryId: typeof menu.categoryId === 'string' ? menu.categoryId : null,
          name: nestedItem.name,
          unitPrice,
          quantity: line.quantity,
          lineTotal,
          note: line.note ?? null,
          modifiers: line.modifiers ?? [],
          createdAt: now,
          updatedAt: now,
          isArchived: false,
          deletedAt: null,
          deletedBy: null,
        },
        nested: nestedItem,
      });
    }

    const subtotal = orderItems.reduce((sum, item) => sum + (item.data.lineTotal as number), 0);
    const totalQuantity = lines.reduce((sum, line) => sum + line.quantity, 0);
    const summary: OrderSummary = {
      id: orderId,
      restaurantId: input.restaurantId,
      status: 'PENDING',
      subtotal,
      total: subtotal,
      totalQuantity,
      submittedAt: now.toDate().toISOString(),
    };
    const orderData = {
      ...summary,
      branchId: session.branchId,
      tableId: session.tableId,
      tableSessionId: session.tableSessionId,
      customerSessionId: input.customerSessionId,
      cartId: input.cartId ?? null,
      items: orderItems.map((item) => item.nested),
      totalAmount: subtotal,
      submittedAt: now,
      acceptedAt: null,
      preparedAt: null,
      servedAt: null,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      deletedAt: null,
      deletedBy: null,
    };
    const orderRef = this.firestore.collection('orders').doc(orderId);
    const nestedOrderRef = this.firestore
      .collection('restaurants')
      .doc(input.restaurantId)
      .collection('orders')
      .doc(orderId);
    if (developmentFallbackEnabled) {
      const nowIso = now.toDate().toISOString();
      transaction.set(
        restaurantRef,
        {
          id: input.restaurantId,
          name: input.restaurantId,
          defaultBranchId: sessionBranchId,
          isActive: true,
          updatedAt: now,
          createdAt: restaurantSnapshot.exists
            ? restaurantSnapshot.data()?.createdAt ?? now
            : now,
          metadataSource: 'development-order-fallback',
        },
        { merge: true },
      );
      transaction.set(
        branchRef,
        {
          id: sessionBranchId,
          restaurantId: input.restaurantId,
          name: sessionBranchId,
          isActive: true,
          updatedAt: now,
          createdAt: branchSnapshot.exists
            ? branchSnapshot.data()?.createdAt ?? now
            : now,
          metadataSource: 'development-order-fallback',
          initializedAt: nowIso,
        },
        { merge: true },
      );
    }
    if (sessionToCreate) {
      transaction.create(sessionToCreate.ref, sessionToCreate.data);
    }
    if (cartToCreate) {
      transaction.create(cartToCreate.ref, cartToCreate.data);
    }
    menuToCreate.forEach((menu) => transaction.create(menu.ref, menu.data));
    transaction.create(orderRef, orderData);
    transaction.create(nestedOrderRef, orderData);
    orderItems.forEach((item) => transaction.create(item.ref, item.data));
    if (cartRef) {
      transaction.update(cartRef, { items: [], subtotal: 0, totalQuantity: 0, updatedAt: now });
    }
    transaction.create(this.firestore.collection('orderRequests').doc(requestId), {
      requestId,
      restaurantId: input.restaurantId,
      orderId,
      cartId: input.cartId ?? null,
      summary,
      createdAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
    });
    return summary;
  }

  private canonicalCartId(customerSessionId: string): string {
    return `cart_${this.resolveCustomerSessionId(customerSessionId)}`;
  }

  private cartReferences(
    customerSessionId: string,
    requestedCartId?: string,
  ): FirebaseFirestore.DocumentReference[] {
    const resolvedCustomerSessionId = this.resolveCustomerSessionId(customerSessionId);
    const cartIds = [
      this.canonicalCartId(resolvedCustomerSessionId),
      requestedCartId?.trim() ?? '',
      resolvedCustomerSessionId,
    ].filter((value, index, values) => value.length > 0 && values.indexOf(value) === index);
    return cartIds.map((cartId) => this.firestore.collection('carts').doc(cartId));
  }

  private resolveCustomerSessionId(customerSessionId: string): string {
    const normalized = customerSessionId.trim();
    return normalized || 'active-customer-session';
  }

  private customerSessionReference(customerSessionId: string): FirebaseFirestore.DocumentReference {
    const resolvedCustomerSessionId = this.resolveCustomerSessionId(customerSessionId);
    return this.firestore.collection('customerSessions').doc(resolvedCustomerSessionId);
  }

  private isDevelopmentSessionFallbackEnabled(): boolean {
    return Boolean(process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true');
  }

  private createDevelopmentMenuItem(
    input: SubmitOrderPayload,
    session: Record<string, unknown>,
    line: CartItemRecord,
    now: Timestamp,
  ): Record<string, unknown> {
    const unitPrice =
      Number.isSafeInteger(line.unitPrice) && (line.unitPrice as number) >= 0
        ? (line.unitPrice as number)
        : 1000;
    return {
      id: line.menuItemId,
      name: line.menuItemId,
      description: 'Development fallback menu item',
      category: 'Menu',
      restaurantId: input.restaurantId,
      branchId: session.branchId ?? input.branchId ?? 'main-branch',
      price: unitPrice,
      isAvailable: true,
      isArchived: false,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
    };
  }

  private createDevelopmentCart(
    input: SubmitOrderPayload,
    lines: CartItemRecord[],
    now: Timestamp,
  ): Record<string, unknown> {
    const cartId = input.cartId ?? `cart_${input.customerSessionId}`;
    const items = lines.map((line) => ({
      menuItemId: line.menuItemId,
      quantity: line.quantity,
      ...(line.note === undefined ? {} : { note: line.note }),
      ...(line.modifiers === undefined ? {} : { modifiers: line.modifiers }),
    }));
    return {
      id: cartId,
      restaurantId: input.restaurantId,
      branchId: input.branchId ?? 'main-branch',
      tableId: input.tableId ?? 'table-12',
      tableSessionId: input.tableSessionId ?? 'active-table-session',
      customerSessionId: input.customerSessionId,
      items,
      totalQuantity: lines.reduce((sum, line) => sum + line.quantity, 0),
      subtotal: 0,
      isArchived: false,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
    };
  }

  private createDevelopmentSession(
    input: SubmitOrderPayload,
    now: Timestamp,
  ): Record<string, unknown> {
    return {
      id: input.customerSessionId,
      customerSessionId: input.customerSessionId,
      restaurantId: input.restaurantId,
      branchId: input.branchId ?? 'main-branch',
      tableId: input.tableId ?? 'table-12',
      tableSessionId: input.tableSessionId ?? 'active-table-session',
      status: 'ACTIVE',
      isActive: true,
      isArchived: false,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000),
    };
  }

  private parseCartItem(value: unknown): CartItemRecord {
    const line = requireRecord(value, 'Cart contains an invalid item.');
    if (
      typeof line.menuItemId !== 'string' ||
      !Number.isSafeInteger(line.quantity) ||
      (line.quantity as number) <= 0
    ) {
      throw new ApplicationError(
        'VALIDATION_FAILED',
        'Cart item must include menuItemId and a positive integer quantity.',
      );
    }
    return line as unknown as CartItemRecord;
  }
}
