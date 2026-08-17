import { Timestamp } from 'firebase/firestore';

import { KitchenOrder, isKitchenOrderStatus } from '../domain/kitchen-order';

export interface KitchenOrderDto {
  readonly id: string;
  readonly restaurantId?: unknown;
  readonly branchId?: unknown;
  readonly tableId?: unknown;
  readonly tableSessionId?: unknown;
  readonly customerSessionId?: unknown;
  readonly status?: unknown;
  readonly subtotal?: unknown;
  readonly total?: unknown;
  readonly totalQuantity?: unknown;
  readonly customerNote?: unknown;
  readonly submittedAt?: unknown;
  readonly createdAt?: unknown;
  readonly updatedAt?: unknown;
}

export function toKitchenOrder(dto: KitchenOrderDto): KitchenOrder | null {
  if (
    !isKitchenOrderStatus(dto.status) ||
    typeof dto.restaurantId !== 'string' ||
    typeof dto.branchId !== 'string' ||
    typeof dto.tableId !== 'string' ||
    typeof dto.tableSessionId !== 'string' ||
    typeof dto.customerSessionId !== 'string'
  ) {
    return null;
  }

  const submittedAt = toDate(dto.submittedAt);
  const createdAt = toDate(dto.createdAt);
  const updatedAt = toDate(dto.updatedAt);
  if (!submittedAt || !createdAt || !updatedAt) {
    return null;
  }

  return {
    id: dto.id,
    restaurantId: dto.restaurantId,
    branchId: dto.branchId,
    tableId: dto.tableId,
    tableSessionId: dto.tableSessionId,
    customerSessionId: dto.customerSessionId,
    status: dto.status,
    total: toNumber(dto.total ?? dto.subtotal),
    totalQuantity: toNumber(dto.totalQuantity),
    customerNote: typeof dto.customerNote === 'string' ? dto.customerNote : null,
    submittedAt,
    createdAt,
    updatedAt,
  };
}

function toDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }
  return null;
}

function toNumber(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}
