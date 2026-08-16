export type ApiErrorCode = 'INVALID_REQUEST' | 'UNAUTHENTICATED' | 'UNAUTHORIZED' | 'NOT_FOUND' | 'VALIDATION_FAILED' | 'RESOURCE_CONFLICT' | 'INTERNAL_ERROR';
export interface ApiRequest<T> { requestId: string; payload: T; timestamp: string; clientVersion?: string; }
export interface ApiError { code: ApiErrorCode; message: string; details?: Record<string, unknown>; }
export type ApiResponse<T> = { success: true; requestId: string; data: T; serverTimestamp: string } | { success: false; requestId: string; error: ApiError; serverTimestamp: string };
export const success = <T>(requestId: string, data: T, now = new Date()): ApiResponse<T> => ({ success: true, requestId, data, serverTimestamp: now.toISOString() });
export const failure = <T>(requestId: string, error: ApiError, now = new Date()): ApiResponse<T> => ({ success: false, requestId, error, serverTimestamp: now.toISOString() });
