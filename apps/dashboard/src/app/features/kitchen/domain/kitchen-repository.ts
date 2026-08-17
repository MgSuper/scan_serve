import { Observable } from 'rxjs';

import { KitchenNextStatus, KitchenOrder, KitchenOrderStatus } from './kitchen-order';

export abstract class KitchenRepository {
  abstract watchActiveOrders(restaurantId: string): Observable<readonly KitchenOrder[]>;

  abstract updateOrderStatus(
    restaurantId: string,
    orderId: string,
    currentStatus: KitchenOrderStatus,
    nextStatus: KitchenNextStatus,
  ): Observable<void>;
}
