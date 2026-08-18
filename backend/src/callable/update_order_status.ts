import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { failure, success, type ApiResponse } from '../shared/api/contracts';
import { ApplicationError } from '../shared/errors/application_error';
import { OrderStatusService } from '../services/order_status_service';
import { parseUpdateOrderStatus } from '../validators/callable_request_validator';

export const updateOrderStatus = onCall(
  { cors: ['http://localhost:4200'] },
  async (request): Promise<ApiResponse<unknown>> => {
  let requestId = 'unknown';
  try {
    const envelope = parseUpdateOrderStatus(request.data);
    requestId = envelope.requestId;
    if (!request.auth?.uid) return failure(requestId, { code: 'UNAUTHENTICATED', message: 'Staff authentication is required.' });
    const order = await new OrderStatusService(getFirestore()).updateOrderStatus(request.auth.uid, envelope.payload);
    return success(requestId, order);
  } catch (error) {
    if (error instanceof ApplicationError) {
      logger.warn('updateOrderStatus rejected', { requestId, code: error.code });
      return failure(requestId, error.toApiError());
    }
    logger.error('updateOrderStatus failed', { requestId, error });
    return failure(requestId, { code: 'INTERNAL_ERROR', message: 'Unable to update order status.' });
    }
  },
);
