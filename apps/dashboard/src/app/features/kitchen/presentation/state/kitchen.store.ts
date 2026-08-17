import { computed, DestroyRef, inject, Injectable, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Subscription, take } from 'rxjs';

import { normalizeRestaurantId } from '../../../../shared/restaurant-context';
import { KitchenOrder, KitchenOrderStatus, NEXT_KITCHEN_STATUS } from '../../domain/kitchen-order';
import { UpdateOrderStatusUseCase } from '../../domain/use-cases/update-order-status.use-case';
import { WatchKitchenQueueUseCase } from '../../domain/use-cases/watch-kitchen-queue.use-case';

export type KitchenFilter = 'ALL' | KitchenOrderStatus;

export interface KitchenColumn {
  readonly status: KitchenOrderStatus;
  readonly orders: readonly KitchenOrder[];
}

@Injectable()
export class KitchenStore {
  private readonly destroyRef = inject(DestroyRef);

  constructor(
    private readonly watchKitchenQueue: WatchKitchenQueueUseCase,
    private readonly updateOrderStatus: UpdateOrderStatusUseCase,
  ) {}
  private queueSubscription: Subscription | null = null;
  private restaurantId = '';

  readonly orders = signal<readonly KitchenOrder[]>([]);
  readonly selectedOrderId = signal<string | null>(null);
  readonly activeFilter = signal<KitchenFilter>('ALL');
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly updatingOrderIds = signal<ReadonlySet<string>>(new Set<string>());

  readonly selectedOrder = computed(() => {
    const selectedId = this.selectedOrderId();
    return selectedId ? (this.orders().find((order) => order.id === selectedId) ?? null) : null;
  });

  readonly columns = computed<readonly KitchenColumn[]>(() => {
    const filter = this.activeFilter();
    const orders = this.orders();
    return (['PENDING', 'ACCEPTED', 'PREPARING'] as const)
      .filter((status) => filter === 'ALL' || filter === status)
      .map((status) => ({
        status,
        orders: orders.filter((order) => order.status === status),
      }));
  });

  initialize(restaurantId: string): void {
    this.restaurantId = normalizeRestaurantId(restaurantId);
    this.queueSubscription?.unsubscribe();
    this.orders.set([]);
    this.selectedOrderId.set(null);
    this.error.set(null);
    this.loading.set(true);

    try {
      this.queueSubscription = this.watchKitchenQueue
        .execute(this.restaurantId)
        .pipe(takeUntilDestroyed(this.destroyRef))
        .subscribe({
          next: (orders) => {
            this.orders.set(orders);
            this.loading.set(false);
            this.error.set(null);
            this.clearMissingSelection(orders);
          },
          error: (error: unknown) => {
            this.loading.set(false);
            this.error.set(this.messageFor(error));
          },
        });
    } catch (error) {
      this.loading.set(false);
      this.error.set(this.messageFor(error));
    }
  }

  retry(): void {
    if (this.restaurantId) {
      this.initialize(this.restaurantId);
    }
  }

  setFilter(filter: KitchenFilter): void {
    this.activeFilter.set(filter);
  }

  selectOrder(orderId: string | null): void {
    this.selectedOrderId.set(orderId);
  }

  advanceOrder(order: KitchenOrder): void {
    if (this.updatingOrderIds().has(order.id)) {
      return;
    }

    const nextStatus = NEXT_KITCHEN_STATUS[order.status];
    this.updatingOrderIds.update((ids) => new Set(ids).add(order.id));
    this.error.set(null);

    this.updateOrderStatus
      .execute(this.restaurantId, order.id, order.status, nextStatus)
      .pipe(take(1), takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: () => this.removeUpdatingOrder(order.id),
        error: (error: unknown) => {
          this.removeUpdatingOrder(order.id);
          this.error.set(this.messageFor(error));
        },
      });
  }

  isUpdating(orderId: string): boolean {
    return this.updatingOrderIds().has(orderId);
  }

  private clearMissingSelection(orders: readonly KitchenOrder[]): void {
    const selectedId = this.selectedOrderId();
    if (selectedId && !orders.some((order) => order.id === selectedId)) {
      this.selectedOrderId.set(null);
    }
  }

  private removeUpdatingOrder(orderId: string): void {
    this.updatingOrderIds.update((ids) => {
      const next = new Set(ids);
      next.delete(orderId);
      return next;
    });
  }

  private messageFor(error: unknown): string {
    return error instanceof Error ? error.message : 'The kitchen queue is unavailable.';
  }
}
