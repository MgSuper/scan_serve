import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { failure, success, type ApiResponse } from '../shared/api/contracts';
import { ApplicationError } from '../shared/errors/application_error';
import { OrderService } from '../services/order_service';
import { parseSubmitOrder } from '../validators/callable_request_validator';

export const submitOrder = onCall(async (request): Promise<ApiResponse<unknown>> => {
  let requestId = 'unknown';
  try {
    const envelope = parseSubmitOrder(request.data);
    requestId = envelope.requestId;
    const order = await new OrderService(getFirestore()).submitOrder(envelope.requestId, envelope.payload);
    return success(envelope.requestId, order);
  } catch (error) {
    if (error instanceof ApplicationError) {
      logger.warn('submitOrder rejected', { requestId, code: error.code });
      return failure(requestId, error.toApiError());
    }
    const details = error instanceof Error
      ? { name: error.name, message: error.message, stack: error.stack }
      : { value: String(error) };
    logger.error('submitOrder failed', { requestId, error: details });
    return failure(requestId, { code: 'INTERNAL_ERROR', message: 'Unable to submit order.' });
  }
});
