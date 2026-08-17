import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { distinctUntilChanged, map } from 'rxjs';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { KitchenFilter, KitchenStore } from '../state/kitchen.store';
import { KitchenOrder, KitchenOrderStatus, NEXT_KITCHEN_STATUS } from '../../domain/kitchen-order';

@Component({
  selector: 'app-kitchen-board',
  standalone: true,
  templateUrl: './kitchen-board.component.html',
  styleUrl: './kitchen-board.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [KitchenStore],
})
export class KitchenBoardComponent {
  readonly store = inject(KitchenStore);
  readonly filters: readonly KitchenFilter[] = ['ALL', 'PENDING', 'ACCEPTED', 'PREPARING'];

  private readonly route = inject(ActivatedRoute);
  private readonly destroyRef = inject(DestroyRef);

  constructor() {
    this.route.paramMap
      .pipe(
        map((params) => params.get('restaurantId') ?? ''),
        distinctUntilChanged(),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((restaurantId) => this.store.initialize(restaurantId));
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

  actionLabel(status: KitchenOrderStatus): string {
    return `Move to ${NEXT_KITCHEN_STATUS[status]}`;
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(value);
  }
}
