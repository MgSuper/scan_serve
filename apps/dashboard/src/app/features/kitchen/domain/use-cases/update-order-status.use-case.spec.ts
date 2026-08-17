import { firstValueFrom, of } from 'rxjs';

import { KitchenRepository } from '../kitchen-repository';
import { KitchenOrderStatus, KitchenNextStatus } from '../kitchen-order';
import { UpdateOrderStatusUseCase } from './update-order-status.use-case';

describe('UpdateOrderStatusUseCase', () => {
  it('delegates a valid transition to the repository', async () => {
    const repository = new FakeKitchenRepository();
    const useCase = new UpdateOrderStatusUseCase(repository);

    await firstValueFrom(useCase.execute('restaurant-1', 'order-1', 'PENDING', 'ACCEPTED'));

    expect(repository.lastUpdate).toEqual({
      restaurantId: 'restaurant-1',
      orderId: 'order-1',
      currentStatus: 'PENDING',
      nextStatus: 'ACCEPTED',
    });
  });

  it('rejects an illegal transition before reaching the repository', () => {
    const repository = new FakeKitchenRepository();
    const useCase = new UpdateOrderStatusUseCase(repository);

    expect(() => useCase.execute('restaurant-1', 'order-1', 'PENDING', 'READY')).toThrowError(
      /cannot transition/i,
    );
    expect(repository.lastUpdate).toBeNull();
  });
});

class FakeKitchenRepository extends KitchenRepository {
  lastUpdate: {
    restaurantId: string;
    orderId: string;
    currentStatus: KitchenOrderStatus;
    nextStatus: KitchenNextStatus;
  } | null = null;

  override watchActiveOrders() {
    return of([]);
  }

  override updateOrderStatus(
    restaurantId: string,
    orderId: string,
    currentStatus: KitchenOrderStatus,
    nextStatus: KitchenNextStatus,
  ) {
    this.lastUpdate = { restaurantId, orderId, currentStatus, nextStatus };
    return of(undefined);
  }
}
