import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { ApplicationError } from '../shared/errors/application_error';
import type { UpdateOrderStatusPayload } from '../validators/callable_request_validator';

const transitions: Record<string, string> = { PENDING: 'ACCEPTED', ACCEPTED: 'PREPARING', PREPARING: 'READY', READY: 'SERVED' };
interface UpdatedOrder { id: string; restaurantId: string; status: string; updatedAt: string; }

const record = (value: unknown, message: string): Record<string, unknown> => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new ApplicationError('INTERNAL_ERROR', message);
  return value as Record<string, unknown>;
};

/** Executes CF-101 and ensures a staff member can update only its tenant's orders. */
export class OrderStatusService {
  public constructor(private readonly firestore: Firestore) {}

  public async updateOrderStatus(authUid: string, input: UpdateOrderStatusPayload): Promise<UpdatedOrder> {
    const now = Timestamp.now();
    const result = await this.firestore.runTransaction(async (transaction) => {
      const staffQuery = this.firestore.collection('staff').where('authUid', '==', authUid).limit(1);
      const orderRef = this.firestore.collection('orders').doc(input.orderId);
      const [staffQuerySnapshot, orderSnapshot] = await Promise.all([transaction.get(staffQuery), transaction.get(orderRef)]);
      if (staffQuerySnapshot.empty) throw new ApplicationError('UNAUTHORIZED', 'No staff profile is associated with this account.');
      if (!orderSnapshot.exists) throw new ApplicationError('NOT_FOUND', 'Order was not found.');
      const staff = record(staffQuerySnapshot.docs[0].data(), 'Staff profile is invalid.');
      const order = record(orderSnapshot.data(), 'Order is invalid.');
      if (staff.restaurantId !== input.restaurantId || order.restaurantId !== input.restaurantId || order.isArchived === true || order.deletedAt) throw new ApplicationError('UNAUTHORIZED', 'Cross-tenant order access is prohibited.');
      if (staff.isActive !== true || staff.isArchived === true || staff.deletedAt) throw new ApplicationError('UNAUTHORIZED', 'Staff member is inactive.');
      if (staff.branchId && staff.branchId !== order.branchId) throw new ApplicationError('UNAUTHORIZED', 'Staff member cannot manage this branch.');
      const roleId = staff.roleId;
      if (typeof roleId !== 'string') throw new ApplicationError('UNAUTHORIZED', 'Staff role is missing.');
      const roleSnapshot = await transaction.get(this.firestore.collection('roles').doc(roleId));
      if (!roleSnapshot.exists) throw new ApplicationError('UNAUTHORIZED', 'Staff role was not found.');
      const role = record(roleSnapshot.data(), 'Role is invalid.');
      if (role.restaurantId !== input.restaurantId || role.isArchived === true || role.deletedAt) throw new ApplicationError('UNAUTHORIZED', 'Staff role does not belong to this restaurant.');
      const permissions = role.permissions;
      if (!Array.isArray(permissions) || !permissions.includes('orders.updateStatus')) throw new ApplicationError('UNAUTHORIZED', 'Staff role lacks order status permission.');
      const current = order.status;
      if (typeof current !== 'string' || transitions[current] !== input.status) throw new ApplicationError('RESOURCE_CONFLICT', `Cannot transition order from ${String(current)} to ${input.status}.`);

      const updates: Record<string, unknown> = { status: input.status, updatedAt: now };
      if (input.status === 'ACCEPTED') updates.acceptedAt = now;
      if (input.status === 'READY') updates.preparedAt = now;
      if (input.status === 'SERVED') updates.servedAt = now;
      transaction.update(orderRef, updates);
      return { id: orderSnapshot.id, restaurantId: input.restaurantId, status: input.status, updatedAt: now.toDate().toISOString() };
    });
    logger.info('updateOrderStatus completed', { authUid, restaurantId: input.restaurantId, orderId: result.id, status: result.status });
    return result;
  }
}
