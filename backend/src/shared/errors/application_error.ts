import type { ApiError, ApiErrorCode } from '../api/contracts';

/** Expected business failure; its safe form is returned to the caller. */
export class ApplicationError extends Error {
  public constructor(
    public readonly code: ApiErrorCode,
    message: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'ApplicationError';
  }

  public toApiError(): ApiError {
    return { code: this.code, message: this.message, details: this.details };
  }
}
