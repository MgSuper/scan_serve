import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

import { KitchenNextStatus, KitchenOrderStatus, NEXT_KITCHEN_STATUS } from '../kitchen-order';
import { KitchenRepository } from '../kitchen-repository';

@Injectable({ providedIn: 'root' })
export class UpdateOrderStatusUseCase {
  constructor(private readonly repository: KitchenRepository) {}

  execute(
    restaurantId: string,
    orderId: string,
    currentStatus: KitchenOrderStatus,
    nextStatus: KitchenNextStatus,
  ): Observable<void> {
    if (!restaurantId.trim() || !orderId.trim()) {
      throw new Error('Restaurant and order identifiers are required.');
    }
    if (NEXT_KITCHEN_STATUS[currentStatus] !== nextStatus) {
      throw new Error(`Order ${orderId} cannot transition from ${currentStatus} to ${nextStatus}.`);
    }
    return this.repository.updateOrderStatus(restaurantId, orderId, currentStatus, nextStatus);
  }
}
