import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

import { KitchenOrder } from '../kitchen-order';
import { KitchenRepository } from '../kitchen-repository';

@Injectable({ providedIn: 'root' })
export class WatchKitchenQueueUseCase {
  constructor(private readonly repository: KitchenRepository) {}

  execute(restaurantId: string): Observable<readonly KitchenOrder[]> {
    if (!restaurantId.trim()) {
      throw new Error('A restaurantId is required to watch the kitchen queue.');
    }
    return this.repository.watchActiveOrders(restaurantId);
  }
}
