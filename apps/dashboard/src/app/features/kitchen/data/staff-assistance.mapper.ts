import { Timestamp } from '@angular/fire/firestore';

import {
  STAFF_ASSISTANCE_TYPES,
  StaffAssistanceRequest,
  StaffAssistanceStatus,
  StaffAssistanceType,
} from '../domain/staff-assistance-request';

export interface StaffAssistanceRequestDto {
  readonly id: string;
  readonly restaurantId?: unknown;
  readonly tableId?: unknown;
  readonly tableSessionId?: unknown;
  readonly customerSessionId?: unknown;
  readonly requestType?: unknown;
  readonly type?: unknown;
  readonly status?: unknown;
  readonly createdAt?: unknown;
  readonly updatedAt?: unknown;
  readonly resolvedAt?: unknown;
  readonly resolvedBy?: unknown;
}

export function toStaffAssistanceRequest(
  dto: StaffAssistanceRequestDto,
): StaffAssistanceRequest | null {
  const type = normalizeType(dto.requestType ?? dto.type);
  const status = normalizeStatus(dto.status);
  if (
    type === null ||
    status === null ||
    typeof dto.restaurantId !== 'string' ||
    typeof dto.tableId !== 'string' ||
    typeof dto.tableSessionId !== 'string' ||
    typeof dto.customerSessionId !== 'string'
  ) {
    return null;
  }

  return {
    id: dto.id,
    restaurantId: dto.restaurantId,
    tableId: dto.tableId,
    tableSessionId: dto.tableSessionId,
    customerSessionId: dto.customerSessionId,
    type,
    status,
    createdAt: toDateOrDefault(dto.createdAt),
    updatedAt: toDateOrDefault(dto.updatedAt),
    resolvedAt: toNullableDate(dto.resolvedAt),
    resolvedBy: typeof dto.resolvedBy === 'string' ? dto.resolvedBy : null,
  };
}

function normalizeType(value: unknown): StaffAssistanceType | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toUpperCase();
  return (STAFF_ASSISTANCE_TYPES as readonly string[]).includes(normalized)
    ? (normalized as StaffAssistanceType)
    : null;
}

function normalizeStatus(value: unknown): StaffAssistanceStatus | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().toUpperCase();
  return normalized === 'OPEN' || normalized === 'ACKNOWLEDGED' || normalized === 'RESOLVED'
    ? (normalized as StaffAssistanceStatus)
    : null;
}

function toDateOrDefault(value: unknown): Date {
  if (value instanceof Timestamp) {
    const date = value.toDate();
    if (!Number.isNaN(date.getTime())) return date;
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value === 'string' || typeof value === 'number') {
    const date = new Date(value);
    if (!Number.isNaN(date.getTime())) return date;
  }
  return new Date();
}

function toNullableDate(value: unknown): Date | null {
  if (value === null || value === undefined) return null;
  return toDateOrDefault(value);
}
