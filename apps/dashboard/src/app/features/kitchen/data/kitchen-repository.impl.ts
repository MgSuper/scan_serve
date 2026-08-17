import { inject, Injectable, Injector, runInInjectionContext } from '@angular/core';
import { collection, collectionData, Firestore, query, where } from '@angular/fire/firestore';
import { Functions, httpsCallable } from '@angular/fire/functions';
import { catchError, from, map, Observable, throwError } from 'rxjs';

import { normalizeRestaurantId } from '../../../shared/restaurant-context';
import {
  KITCHEN_ORDER_STATUSES,
  KitchenNextStatus,
  KitchenOrder,
  KitchenOrderStatus,
} from '../domain/kitchen-order';
import { KitchenRepository } from '../domain/kitchen-repository';
import { KitchenOrderDto, toKitchenOrder } from './kitchen-order.mapper';

interface UpdateOrderStatusRequest {
  readonly requestId: string;
  readonly timestamp: string;
  readonly payload: {
    readonly restaurantId: string;
    readonly orderId: string;
    readonly status: KitchenNextStatus;
  };
}

interface ApiError {
  readonly code?: unknown;
  readonly message?: unknown;
}

interface ApiResponse<T> {
  readonly success?: unknown;
  readonly data?: T;
  readonly error?: ApiError;
}

@Injectable({ providedIn: 'root' })
export class KitchenRepositoryImpl extends KitchenRepository {
  private readonly firestore = inject(Firestore);
  private readonly functions = inject(Functions);
  private readonly injector = inject(Injector);

  watchActiveOrders(restaurantId: string): Observable<readonly KitchenOrder[]> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    return runInInjectionContext(this.injector, () => {
      const orders = collection(this.firestore, 'orders');
      const restaurantOrders = query(
        orders,
        where('restaurantId', '==', resolvedRestaurantId),
        where('status', 'in', KITCHEN_ORDER_STATUSES),
      );

      return collectionData(restaurantOrders, { idField: 'id' }).pipe(
        map((documents) =>
          documents
            .map((document) => toKitchenOrder(document as KitchenOrderDto))
            .filter((order): order is KitchenOrder => order !== null)
            .sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime()),
        ),
        catchError((error: unknown) =>
          throwError(() => new Error(this.readableFirestoreError(error))),
        ),
      );
    });
  }

  updateOrderStatus(
    restaurantId: string,
    orderId: string,
    currentStatus: KitchenOrderStatus,
    nextStatus: KitchenNextStatus,
  ): Observable<void> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    const callable = runInInjectionContext(this.injector, () =>
      httpsCallable<UpdateOrderStatusRequest, ApiResponse<unknown>>(
        this.functions,
        'updateOrderStatus',
      ),
    );
    const request: UpdateOrderStatusRequest = {
      requestId: `${orderId}-${Date.now()}`,
      timestamp: new Date().toISOString(),
      payload: {
        restaurantId: resolvedRestaurantId,
        orderId,
        status: nextStatus,
      },
    };

    return from(callable(request)).pipe(
      map((result) => result.data),
      map((response) => {
        if (response.success !== true) {
          throw new Error(this.readableCallableError(response.error));
        }
        return undefined;
      }),
      catchError((error: unknown) =>
        throwError(() =>
          error instanceof Error ? error : new Error('Unable to update the order status.'),
        ),
      ),
    );
  }

  private readableFirestoreError(error: unknown): string {
    if (this.isFirebaseError(error) && error.code === 'permission-denied') {
      return 'You do not have permission to view this kitchen queue.';
    }
    return 'The kitchen queue is temporarily unavailable.';
  }

  private readableCallableError(error: ApiError | undefined): string {
    return typeof error?.message === 'string'
      ? error.message
      : 'Unable to update the order status.';
  }

  private isFirebaseError(error: unknown): error is { readonly code: string } {
    return typeof error === 'object' && error !== null && 'code' in error;
  }
}
