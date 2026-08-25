export const KITCHEN_ORDER_STATUSES = [
  'PENDING',
  'ACCEPTED',
  'PREPARING',
  'READY',
  'SERVED',
] as const;

export type KitchenOrderStatus = (typeof KITCHEN_ORDER_STATUSES)[number];
export type OrderStatus = KitchenOrderStatus | 'CANCELLED';
export type KitchenNextStatus = Exclude<KitchenOrderStatus, 'PENDING' | 'SERVED'> | 'SERVED';

export interface KitchenOrder {
  readonly id: string;
  readonly restaurantId: string;
  readonly branchId: string;
  readonly tableId: string;
  readonly tableSessionId: string;
  readonly customerSessionId: string;
  readonly status: KitchenOrderStatus;
  readonly total: number;
  readonly totalQuantity: number;
  readonly customerNote: string | null;
  readonly submittedAt: Date;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export const NEXT_KITCHEN_STATUS: Readonly<Record<KitchenOrderStatus, KitchenNextStatus | null>> = {
  PENDING: 'ACCEPTED',
  ACCEPTED: 'PREPARING',
  PREPARING: 'READY',
  READY: 'SERVED',
  SERVED: null,
};

export function isKitchenOrderStatus(value: unknown): value is KitchenOrderStatus {
  return typeof value === 'string' && (KITCHEN_ORDER_STATUSES as readonly string[]).includes(value);
}
