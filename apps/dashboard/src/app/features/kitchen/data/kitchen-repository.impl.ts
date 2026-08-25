import { inject, Injectable, Injector, runInInjectionContext } from '@angular/core';
import {
  collection,
  doc,
  Firestore,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from '@angular/fire/firestore';
import { Functions, httpsCallable } from '@angular/fire/functions';
import { catchError, from, map, Observable, of, throwError } from 'rxjs';

import { normalizeRestaurantId } from '../../../shared/restaurant-context';
import {
  KITCHEN_ORDER_STATUSES,
  KitchenNextStatus,
  KitchenOrder,
  KitchenOrderStatus,
} from '../domain/kitchen-order';
import { KitchenRepository } from '../domain/kitchen-repository';
import { StaffAssistanceRequest } from '../domain/staff-assistance-request';
import { KitchenOrderDto, toKitchenOrder } from './kitchen-order.mapper';
import { StaffAssistanceRequestDto, toStaffAssistanceRequest } from './staff-assistance.mapper';

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
      return new Observable<KitchenOrderDto[]>((observer) => {
        const restaurantOrders = query(
          collection(this.firestore, `restaurants/${resolvedRestaurantId}/orders`),
          where('restaurantId', '==', resolvedRestaurantId),
          where('status', 'in', KITCHEN_ORDER_STATUSES),
        );

        const unsubscribe = onSnapshot(
          restaurantOrders,
          (snapshot) => {
            const documents = snapshot.docs.map(
              (snapshotDocument) =>
                ({ id: snapshotDocument.id, ...snapshotDocument.data() }) as KitchenOrderDto,
            );
            observer.next(documents);
          },
          (error) => observer.error(error),
        );

        return () => unsubscribe();
      }).pipe(
        map((documents) =>
          documents
            .map((document) => toKitchenOrder(document))
            .filter((order): order is KitchenOrder => order !== null)
            .sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime()),
        ),
        catchError((error: unknown) => {
          console.error('[Firestore Kitchen Stream Error]', error);
          return of([] as readonly KitchenOrder[]);
        }),
      );
    });
  }

  watchAssistanceRequests(restaurantId: string): Observable<readonly StaffAssistanceRequest[]> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);

    return runInInjectionContext(this.injector, () => {
      return new Observable<StaffAssistanceRequestDto[]>((observer) => {
        const requestsQuery = query(
          collection(this.firestore, `restaurants/${resolvedRestaurantId}/waiterRequests`),
          where('status', 'in', ['OPEN', 'ACKNOWLEDGED']),
        );

        const unsubscribe = onSnapshot(
          requestsQuery,
          (snapshot) => {
            const documents = snapshot.docs.map(
              (snapshotDocument) =>
                ({
                  id: snapshotDocument.id,
                  ...snapshotDocument.data(),
                }) as StaffAssistanceRequestDto,
            );
            observer.next(documents);
          },
          (error) => observer.error(error),
        );

        return () => unsubscribe();
      }).pipe(
        map((documents) =>
          documents
            .map((document) => toStaffAssistanceRequest(document))
            .filter((request): request is StaffAssistanceRequest => request !== null)
            .sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime()),
        ),
        catchError((error: unknown) => {
          console.error('[Firestore Assistance Stream Error]', error);
          return of([] as readonly StaffAssistanceRequest[]);
        }),
      );
    });
  }

  resolveAssistanceRequest(restaurantId: string, requestId: string): Observable<void> {
    const resolvedRestaurantId = normalizeRestaurantId(restaurantId);
    const requestReference = runInInjectionContext(this.injector, () =>
      doc(this.firestore, `restaurants/${resolvedRestaurantId}/waiterRequests/${requestId}`),
    );

    return from(
      runInInjectionContext(this.injector, () =>
        updateDoc(requestReference, {
          status: 'RESOLVED',
          resolvedAt: serverTimestamp(),
        }),
      ),
    ).pipe(
      map(() => undefined),
      catchError((error: unknown) =>
        throwError(() =>
          error instanceof Error ? error : new Error('Unable to resolve the assistance request.'),
        ),
      ),
    );
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
