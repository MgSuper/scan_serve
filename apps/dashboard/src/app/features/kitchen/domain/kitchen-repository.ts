import { Observable } from 'rxjs';

import { KitchenNextStatus, KitchenOrder, KitchenOrderStatus } from './kitchen-order';
import { StaffAssistanceRequest } from './staff-assistance-request';

export abstract class KitchenRepository {
  abstract watchActiveOrders(restaurantId: string): Observable<readonly KitchenOrder[]>;

  abstract updateOrderStatus(
    restaurantId: string,
    orderId: string,
    currentStatus: KitchenOrderStatus,
    nextStatus: KitchenNextStatus,
  ): Observable<void>;

  abstract watchAssistanceRequests(
    restaurantId: string,
  ): Observable<readonly StaffAssistanceRequest[]>;

  abstract resolveAssistanceRequest(restaurantId: string, requestId: string): Observable<void>;
}
