import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  effect,
  inject,
  OnDestroy,
  signal,
} from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { distinctUntilChanged, map } from 'rxjs';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import {
  KITCHEN_ORDER_STATUSES,
  KitchenOrder,
  KitchenOrderStatus,
  NEXT_KITCHEN_STATUS,
} from '../../domain/kitchen-order';
import { StaffAssistanceRequest } from '../../domain/staff-assistance-request';
import { KitchenAudioNotificationService } from './kitchen-audio-notification.service';
import { KitchenFilter, KitchenStore } from '../state/kitchen.store';

interface NewOrderNotification {
  readonly orderId: string;
  readonly tableId: string;
}

@Component({
  selector: 'app-kitchen-board',
  standalone: true,
  templateUrl: './kitchen-board.component.html',
  styleUrl: './kitchen-board.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [KitchenStore],
})
export class KitchenBoardComponent implements OnDestroy {
  readonly store = inject(KitchenStore);
  readonly filters: readonly KitchenFilter[] = ['ALL', ...KITCHEN_ORDER_STATUSES];
  readonly newOrderIds = signal<ReadonlySet<string>>(new Set<string>());
  readonly toast = signal<NewOrderNotification | null>(null);

  private readonly route = inject(ActivatedRoute);
  private readonly destroyRef = inject(DestroyRef);
  private readonly audioNotifications = inject(KitchenAudioNotificationService);
  private readonly newOrderTimers = new Map<string, ReturnType<typeof setTimeout>>();
  private previousOrderIds = new Set<string>();
  private hasReceivedFirstSnapshot = false;
  private toastTimer: ReturnType<typeof setTimeout> | null = null;

  constructor() {
    this.route.paramMap
      .pipe(
        map((params) => params.get('restaurantId') ?? ''),
        distinctUntilChanged(),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((restaurantId) => {
        this.resetNotifications();
        this.store.initialize(restaurantId);
      });

    effect(() => {
      const orders = this.store.orders();
      if (this.store.loading()) {
        return;
      }
      this.handleOrderSnapshot(orders);
    });
  }

  ngOnDestroy(): void {
    this.resetNotifications();
  }

  setFilter(filter: KitchenFilter): void {
    this.store.setFilter(filter);
  }

  selectOrder(orderId: string): void {
    this.store.selectOrder(orderId);
  }

  clearSelection(): void {
    this.store.selectOrder(null);
  }

  advanceOrder(order: KitchenOrder): void {
    this.store.advanceOrder(order);
  }

  resolveAssistance(request: StaffAssistanceRequest): void {
    this.store.resolveAssistance(request);
  }

  assistanceLabel(type: StaffAssistanceRequest['type']): string {
    return type === 'PAYMENT' ? 'Payment assistance' : 'Waiter assistance';
  }

  formatRequestTime(date: Date): string {
    return new Intl.DateTimeFormat('en-US', {
      hour: 'numeric',
      minute: '2-digit',
    }).format(date);
  }

  dismissToast(): void {
    if (this.toastTimer) {
      clearTimeout(this.toastTimer);
      this.toastTimer = null;
    }
    this.toast.set(null);
  }

  actionLabel(status: KitchenOrderStatus): string {
    const nextStatus = NEXT_KITCHEN_STATUS[status];
    return nextStatus === null ? 'Served' : `Move to ${nextStatus}`;
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(value);
  }

  private handleOrderSnapshot(orders: readonly KitchenOrder[]): void {
    const currentOrderIds = new Set(orders.map((order) => order.id));
    if (!this.hasReceivedFirstSnapshot) {
      this.previousOrderIds = currentOrderIds;
      this.hasReceivedFirstSnapshot = true;
      return;
    }

    const newOrders = orders.filter((order) => !this.previousOrderIds.has(order.id));
    this.previousOrderIds = currentOrderIds;
    for (const order of newOrders) {
      this.notifyNewOrder(order);
    }
  }

  private notifyNewOrder(order: KitchenOrder): void {
    this.newOrderIds.update((ids) => new Set(ids).add(order.id));
    const existingTimer = this.newOrderTimers.get(order.id);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }
    this.newOrderTimers.set(
      order.id,
      setTimeout(() => {
        this.newOrderIds.update((ids) => {
          const next = new Set(ids);
          next.delete(order.id);
          return next;
        });
        this.newOrderTimers.delete(order.id);
      }, 5000),
    );

    this.audioNotifications.playNewOrderCue();
    this.toast.set({ orderId: order.id, tableId: order.tableId });
    if (this.toastTimer) {
      clearTimeout(this.toastTimer);
    }
    this.toastTimer = setTimeout(() => {
      this.toast.set(null);
      this.toastTimer = null;
    }, 5000);
  }

  private resetNotifications(): void {
    for (const timer of this.newOrderTimers.values()) {
      clearTimeout(timer);
    }
    this.newOrderTimers.clear();
    this.newOrderIds.set(new Set<string>());
    this.previousOrderIds = new Set<string>();
    this.hasReceivedFirstSnapshot = false;
    this.dismissToast();
  }
}
