import { TestBed } from '@angular/core/testing';
import { of } from 'rxjs';

import { KitchenOrder } from '../../domain/kitchen-order';
import { ResolveAssistanceRequestUseCase } from '../../domain/use-cases/resolve-assistance-request.use-case';
import { UpdateOrderStatusUseCase } from '../../domain/use-cases/update-order-status.use-case';
import { WatchAssistanceRequestsUseCase } from '../../domain/use-cases/watch-assistance-requests.use-case';
import { WatchKitchenQueueUseCase } from '../../domain/use-cases/watch-kitchen-queue.use-case';
import { KitchenStore } from './kitchen.store';

describe('KitchenStore', () => {
  const order: KitchenOrder = {
    id: 'order-1',
    restaurantId: 'restaurant-1',
    branchId: 'branch-1',
    tableId: 'table-4',
    tableSessionId: 'table-session-1',
    customerSessionId: 'customer-session-1',
    status: 'PENDING',
    total: 24,
    totalQuantity: 2,
    customerNote: null,
    submittedAt: new Date('2026-01-01T10:00:00Z'),
    createdAt: new Date('2026-01-01T10:00:00Z'),
    updatedAt: new Date('2026-01-01T10:00:00Z'),
  };

  it('updates real-time orders and derives columns and selection', () => {
    TestBed.configureTestingModule({
      providers: [
        KitchenStore,
        {
          provide: WatchKitchenQueueUseCase,
          useValue: { execute: () => of([order]) },
        },
        {
          provide: UpdateOrderStatusUseCase,
          useValue: { execute: () => of(undefined) },
        },
        {
          provide: WatchAssistanceRequestsUseCase,
          useValue: { execute: () => of([]) },
        },
        {
          provide: ResolveAssistanceRequestUseCase,
          useValue: { execute: () => of(undefined) },
        },
      ],
    });

    const store = TestBed.inject(KitchenStore);
    store.initialize('restaurant-1');
    store.selectOrder(order.id);
    store.setFilter('PENDING');

    expect(store.loading()).toBeFalse();
    expect(store.error()).toBeNull();
    expect(store.columns()).toEqual([{ status: 'PENDING', orders: [order] }]);
    expect(store.selectedOrder()).toEqual(order);
  });
});
