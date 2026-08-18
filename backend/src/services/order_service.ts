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
    const resolvedCartId = input.cartId ?? `cart_${requestId}`;
    const resolvedInput = { ...input, cartId: resolvedCartId };
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
    const cartId = input.cartId;
    const result = await this.firestore.runTransaction(async (transaction) => {
      const sessionRef = this.firestore.collection('customerSessions').doc(input.customerSessionId);
      const cartRef = this.firestore.collection('carts').doc(cartId);
      const idempotencyRef = this.firestore.collection('orderRequests').doc(requestId);
      const [requestSnapshot, sessionSnapshot, cartSnapshot] = await Promise.all([
        transaction.get(idempotencyRef),
        transaction.get(sessionRef),
        transaction.get(cartRef),
      ]);

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
      const sessionRef = this.firestore.collection('customerSessions').doc(input.customerSessionId);
      const [requestSnapshot, sessionSnapshot] = await Promise.all([
        transaction.get(idempotencyRef),
        transaction.get(sessionRef),
      ]);
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
      return this.createOrderInTransaction(
        transaction,
        requestId,
        input,
        session,
        lines,
        now,
        undefined,
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
  ): Promise<OrderSummary> {
    const menuRefs = lines.map((line) => ({
      legacy: this.firestore.collection('menuItems').doc(line.menuItemId),
      nested: this.firestore
        .collection('restaurants')
        .doc(input.restaurantId)
        .collection('menu')
        .doc(line.menuItemId),
    }));
    const menuSnapshots = await Promise.all(
      menuRefs.map(async ({ legacy, nested }) => {
        const [legacySnapshot, nestedSnapshot] = await Promise.all([
          transaction.get(legacy),
          transaction.get(nested),
        ]);
        return legacySnapshot.exists ? legacySnapshot : nestedSnapshot;
      }),
    );
    const orderId = this.firestore.collection('orders').doc().id;
    const orderItems: Array<{
      ref: FirebaseFirestore.DocumentReference;
      data: Record<string, unknown>;
      nested: Record<string, unknown>;
    }> = [];

    for (let index = 0; index < menuSnapshots.length; index += 1) {
      const snapshot = menuSnapshots[index];
      if (!snapshot.exists) {
        throw new ApplicationError('NOT_FOUND', 'A menu item is no longer available.');
      }
      const menu = requireRecord(snapshot.data(), 'Menu item is invalid.');
      if (
        menu.restaurantId !== input.restaurantId ||
        menu.branchId !== session.branchId ||
        menu.isAvailable !== true ||
        menu.isArchived === true ||
        menu.deletedAt
      ) {
        throw new ApplicationError('VALIDATION_FAILED', 'A menu item is unavailable.');
      }
      const unitPrice = menu.price;
      if (!Number.isSafeInteger(unitPrice) || (unitPrice as number) < 0) {
        throw new ApplicationError('INTERNAL_ERROR', 'Menu item price is invalid.');
      }
      const line = lines[index];
      const orderItemRef = this.firestore.collection('orderItems').doc();
      const lineTotal = (unitPrice as number) * line.quantity;
      const nestedItem = {
        itemId: snapshot.id,
        menuItemId: snapshot.id,
        name: typeof menu.name === 'string' ? menu.name : snapshot.id,
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
          menuItemId: snapshot.id,
          categoryId: typeof menu.categoryId === 'string' ? menu.categoryId : null,
          name: menu.name,
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
    if (sessionToCreate) {
      transaction.create(sessionToCreate.ref, sessionToCreate.data);
    }
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

  private isDevelopmentSessionFallbackEnabled(): boolean {
    return Boolean(process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true');
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
