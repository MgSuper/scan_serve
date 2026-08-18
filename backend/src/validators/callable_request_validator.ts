import { ApplicationError } from '../shared/errors/application_error';
import type { ApiRequest } from '../shared/api/contracts';

export interface SubmitOrderItem {
  menuItemId: string;
  quantity: number;
  note?: string;
  modifiers?: string[];
}

export interface SubmitOrderPayload {
  restaurantId: string;
  customerSessionId: string;
  cartId?: string;
  branchId?: string;
  tableId?: string;
  tableSessionId?: string;
  items?: SubmitOrderItem[];
}

export interface UpdateOrderStatusPayload {
  restaurantId: string;
  orderId: string;
  status: 'ACCEPTED' | 'PREPARING' | 'READY' | 'SERVED';
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const requireString = (source: Record<string, unknown>, field: string): string => {
  const value = source[field];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ApplicationError('INVALID_REQUEST', `${field} must be a non-empty string.`);
  }
  return value;
};

const optionalString = (source: Record<string, unknown>, field: string): string | undefined => {
  const value = source[field];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'string') {
    throw new ApplicationError('INVALID_REQUEST', `${field} must be a string when provided.`);
  }
  const normalized = value.trim();
  return normalized.length === 0 ? undefined : normalized;
};

const parseItems = (value: unknown): SubmitOrderItem[] | undefined => {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value) || value.length === 0) {
    throw new ApplicationError('INVALID_REQUEST', 'items must contain at least one item.');
  }
  return value.map((rawItem) => {
    if (!isRecord(rawItem)) {
      throw new ApplicationError('INVALID_REQUEST', 'Each order item must be an object.');
    }
    const quantity = rawItem.quantity;
    if (!Number.isSafeInteger(quantity) || (quantity as number) <= 0) {
      throw new ApplicationError('INVALID_REQUEST', 'Each order item quantity must be a positive integer.');
    }
    const note = rawItem.note;
    if (note !== undefined && note !== null && typeof note !== 'string') {
      throw new ApplicationError('INVALID_REQUEST', 'Order item note must be a string.');
    }
    const modifiers = rawItem.modifiers;
    if (
      modifiers !== undefined &&
      modifiers !== null &&
      (!Array.isArray(modifiers) || modifiers.some((modifier) => typeof modifier !== 'string'))
    ) {
      throw new ApplicationError('INVALID_REQUEST', 'Order item modifiers must be strings.');
    }
    return {
      menuItemId: requireString(rawItem, 'menuItemId'),
      quantity: quantity as number,
      ...(note === undefined || note === null ? {} : { note }),
      ...(modifiers === undefined || modifiers === null ? {} : { modifiers }),
    };
  });
};

export const parseEnvelope = <T>(
  data: unknown,
  parsePayload: (payload: Record<string, unknown>) => T,
): ApiRequest<T> => {
  if (!isRecord(data) || !isRecord(data.payload)) {
    throw new ApplicationError('INVALID_REQUEST', 'requestId, payload, and timestamp are required.');
  }
  const requestId = requireString(data, 'requestId');
  const timestamp = requireString(data, 'timestamp');
  if (Number.isNaN(Date.parse(timestamp))) {
    throw new ApplicationError('INVALID_REQUEST', 'timestamp must be an ISO-8601 date.');
  }
  const clientVersion = data.clientVersion;
  if (clientVersion !== undefined && typeof clientVersion !== 'string') {
    throw new ApplicationError('INVALID_REQUEST', 'clientVersion must be a string.');
  }
  return { requestId, timestamp, clientVersion, payload: parsePayload(data.payload) };
};

export const parseSubmitOrder = (data: unknown): ApiRequest<SubmitOrderPayload> =>
  parseEnvelope(data, (payload) => {
    // Accept the canonical payload shape and tolerate one extra `payload` or
    // `data` wrapper produced by generic callable clients.
    const nestedPayload = isRecord(payload.payload)
      ? payload.payload
      : isRecord(payload.data)
        ? payload.data
        : payload;
    const items = parseItems(nestedPayload.items ?? nestedPayload.lines);
    const cartId = optionalString(nestedPayload, 'cartId');
    if (!cartId && !items) {
      throw new ApplicationError('INVALID_REQUEST', 'cartId or items is required.');
    }
    return {
      restaurantId: requireString(nestedPayload, 'restaurantId'),
      customerSessionId: requireString(nestedPayload, 'customerSessionId'),
      ...(cartId ? { cartId } : {}),
      ...(items ? { items } : {}),
      ...(optionalString(nestedPayload, 'branchId')
        ? { branchId: optionalString(nestedPayload, 'branchId') }
        : {}),
      ...(optionalString(nestedPayload, 'tableId')
        ? { tableId: optionalString(nestedPayload, 'tableId') }
        : {}),
      ...(optionalString(nestedPayload, 'tableSessionId')
        ? { tableSessionId: optionalString(nestedPayload, 'tableSessionId') }
        : {}),
    };
  });

export const parseUpdateOrderStatus = (data: unknown): ApiRequest<UpdateOrderStatusPayload> =>
  parseEnvelope(data, (payload) => {
    const status = requireString(payload, 'status');
    if (!['ACCEPTED', 'PREPARING', 'READY', 'SERVED'].includes(status)) {
      throw new ApplicationError('INVALID_REQUEST', 'status must be ACCEPTED, PREPARING, READY, or SERVED.');
    }
    return {
      restaurantId: requireString(payload, 'restaurantId'),
      orderId: requireString(payload, 'orderId'),
      status: status as UpdateOrderStatusPayload['status'],
    };
  });
