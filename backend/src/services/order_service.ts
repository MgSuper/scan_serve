import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { ApplicationError } from '../shared/errors/application_error';
import type { SubmitOrderPayload } from '../validators/callable_request_validator';

interface CartItemRecord { menuItemId: string; quantity: number; note?: string; modifiers?: string[]; }
interface OrderSummary { id: string; restaurantId: string; status: 'PENDING'; subtotal: number; total: number; totalQuantity: number; submittedAt: string; }

const requireRecord = (value: unknown, message: string): Record<string, unknown> => {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new ApplicationError('VALIDATION_FAILED', message);
  return value as Record<string, unknown>;
};

/** Executes CF-002 using one transaction for all mutable order state. */
export class OrderService {
  public constructor(private readonly firestore: Firestore) {}

  public async submitOrder(requestId: string, input: SubmitOrderPayload): Promise<OrderSummary> {
    const now = Timestamp.now();
    const result = await this.firestore.runTransaction(async (transaction) => {
      const sessionRef = this.firestore.collection('customerSessions').doc(input.customerSessionId);
      const cartRef = this.firestore.collection('carts').doc(input.cartId);
      const idempotencyRef = this.firestore.collection('orderRequests').doc(requestId);
      const [requestSnapshot, sessionSnapshot, cartSnapshot] = await Promise.all([
        transaction.get(idempotencyRef), transaction.get(sessionRef), transaction.get(cartRef),
      ]);

      if (requestSnapshot.exists) {
        const previous = requireRecord(requestSnapshot.data(), 'Stored request is invalid.');
        if (previous.restaurantId !== input.restaurantId) throw new ApplicationError('UNAUTHORIZED', 'Request belongs to another restaurant.');
        return previous.summary as OrderSummary;
      }
      if (!sessionSnapshot.exists) throw new ApplicationError('NOT_FOUND', 'Customer session was not found.');
      const session = requireRecord(sessionSnapshot.data(), 'Customer session is invalid.');
      if (session.restaurantId !== input.restaurantId || session.status !== 'ACTIVE' || session.isArchived === true || session.deletedAt) throw new ApplicationError('UNAUTHORIZED', 'Customer session is not active for this restaurant.');
      const expiresAt = session.expiresAt as Timestamp | undefined;
      if (expiresAt && expiresAt.toMillis() <= now.toMillis()) throw new ApplicationError('VALIDATION_FAILED', 'Customer session has expired.');

      if (!cartSnapshot.exists) throw new ApplicationError('NOT_FOUND', 'Cart was not found.');
      const cart = requireRecord(cartSnapshot.data(), 'Cart is invalid.');
      if (cart.restaurantId !== input.restaurantId || cart.customerSessionId !== input.customerSessionId || cart.isArchived === true || cart.deletedAt) throw new ApplicationError('UNAUTHORIZED', 'Cart does not belong to this customer session.');
      const cartItems = cart.items;
      if (!Array.isArray(cartItems) || cartItems.length === 0) throw new ApplicationError('VALIDATION_FAILED', 'Cart must contain at least one item.');

      const lines = cartItems.map((item) => {
        const line = requireRecord(item, 'Cart contains an invalid item.');
        if (typeof line.menuItemId !== 'string' || !Number.isSafeInteger(line.quantity) || (line.quantity as number) <= 0) throw new ApplicationError('VALIDATION_FAILED', 'Cart item must include menuItemId and a positive integer quantity.');
        return line as unknown as CartItemRecord;
      });
      const menuRefs = lines.map((line) => this.firestore.collection('menuItems').doc(line.menuItemId));
      const menuSnapshots = await Promise.all(menuRefs.map((reference) => transaction.get(reference)));
      const orderId = this.firestore.collection('orders').doc().id;
      const orderItems = menuSnapshots.map((snapshot, index) => {
        if (!snapshot.exists) throw new ApplicationError('NOT_FOUND', 'A menu item is no longer available.');
        const menu = requireRecord(snapshot.data(), 'Menu item is invalid.');
        if (menu.restaurantId !== input.restaurantId || menu.branchId !== session.branchId || menu.isAvailable !== true || menu.isArchived === true || menu.deletedAt) throw new ApplicationError('VALIDATION_FAILED', 'A menu item is unavailable.');
        const quantity = lines[index].quantity;
        const unitPrice = menu.price;
        if (!Number.isSafeInteger(unitPrice) || (unitPrice as number) < 0) throw new ApplicationError('INTERNAL_ERROR', 'Menu item price is invalid.');
        const orderItemRef = this.firestore.collection('orderItems').doc();
        return { ref: orderItemRef, data: { id: orderItemRef.id, orderId, restaurantId: input.restaurantId, branchId: session.branchId, menuItemId: snapshot.id, categoryId: menu.categoryId, name: menu.name, unitPrice, quantity, lineTotal: (unitPrice as number) * quantity, note: lines[index].note ?? null, modifiers: lines[index].modifiers ?? [], createdAt: now, updatedAt: now, isArchived: false, deletedAt: null, deletedBy: null } };
      });
      const subtotal = orderItems.reduce((sum, item) => sum + item.data.lineTotal, 0);
      const totalQuantity = lines.reduce((sum, line) => sum + line.quantity, 0);
      const orderRef = this.firestore.collection('orders').doc(orderId);
      const summary: OrderSummary = { id: orderId, restaurantId: input.restaurantId, status: 'PENDING', subtotal, total: subtotal, totalQuantity, submittedAt: now.toDate().toISOString() };

      transaction.create(orderRef, { ...summary, branchId: session.branchId, tableId: session.tableId, tableSessionId: session.tableSessionId, customerSessionId: input.customerSessionId, customerNote: null, submittedAt: now, acceptedAt: null, preparedAt: null, servedAt: null, createdAt: now, updatedAt: now, isArchived: false, deletedAt: null, deletedBy: null });
      orderItems.forEach(({ ref, data }) => transaction.create(ref, data));
      transaction.update(cartRef, { items: [], subtotal: 0, totalQuantity: 0, updatedAt: now });
      transaction.create(idempotencyRef, { requestId, restaurantId: input.restaurantId, orderId, summary, createdAt: now, expiresAt: Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000) });
      return summary;
    });
    logger.info('submitOrder completed', { requestId, restaurantId: input.restaurantId, orderId: result.id });
    return result;
  }
}
