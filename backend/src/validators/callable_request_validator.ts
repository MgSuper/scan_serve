import { ApplicationError } from '../shared/errors/application_error';
import type { ApiRequest } from '../shared/api/contracts';

export interface SubmitOrderPayload { restaurantId: string; customerSessionId: string; cartId: string; }
export interface UpdateOrderStatusPayload { restaurantId: string; orderId: string; status: 'ACCEPTED' | 'PREPARING' | 'READY' | 'SERVED'; }

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
const requireString = (source: Record<string, unknown>, field: string): string => {
  const value = source[field];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new ApplicationError('INVALID_REQUEST', `${field} must be a non-empty string.`);
  }
  return value;
};

export const parseEnvelope = <T>(data: unknown, parsePayload: (payload: Record<string, unknown>) => T): ApiRequest<T> => {
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

export const parseSubmitOrder = (data: unknown): ApiRequest<SubmitOrderPayload> => parseEnvelope(data, (payload) => ({
  restaurantId: requireString(payload, 'restaurantId'), customerSessionId: requireString(payload, 'customerSessionId'), cartId: requireString(payload, 'cartId'),
}));

export const parseUpdateOrderStatus = (data: unknown): ApiRequest<UpdateOrderStatusPayload> => parseEnvelope(data, (payload) => {
  const status = requireString(payload, 'status');
  if (!['ACCEPTED', 'PREPARING', 'READY', 'SERVED'].includes(status)) {
    throw new ApplicationError('INVALID_REQUEST', 'status must be ACCEPTED, PREPARING, READY, or SERVED.');
  }
  return { restaurantId: requireString(payload, 'restaurantId'), orderId: requireString(payload, 'orderId'), status: status as UpdateOrderStatusPayload['status'] };
});
