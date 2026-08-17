import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';
import 'package:scan_serve/features/customer/domain/models.dart';
import 'package:scan_serve/features/customer/presentation/customer_cubit.dart';

void main() {
  test('CustomerCubit reflects a later active-order update', () async {
    final repository = _LiveRepository();
    final cubit = CustomerCubit(repository);
    final states = <CustomerState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load();
    repository.updates.add(
      CustomerOrder(
        id: 'ORD-LIVE',
        lines: const [
          CartLine(
            item: MenuItem(
              id: 'pho',
              category: 'Mains',
              name: 'Phở bò',
              description: 'Noodle soup',
              price: 85000,
            ),
            quantity: 1,
          ),
        ],
        status: OrderStatus.preparing,
        createdAt: DateTime(2026),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      states.any((state) => state.order?.status == OrderStatus.preparing),
      isTrue,
    );

    await subscription.cancel();
    await cubit.close();
    await repository.dispose();
  });
}

class _LiveRepository implements CustomerRepository {
  final updates = StreamController<CustomerOrder?>.broadcast();

  @override
  Future<List<MenuItem>> getActiveMenu() async => const [];

  @override
  Stream<CustomerOrder?> getActiveOrder() => Stream.multi((multi) {
    multi.add(null);
    updates.stream.listen(multi.add, onDone: multi.close);
  });

  @override
  Future<CustomerOrder> submitOrder(List<CartLine> lines) async =>
      CustomerOrder(
        id: 'ORD-1',
        lines: lines,
        status: OrderStatus.pending,
        createdAt: DateTime(2026),
      );

  @override
  Future<void> requestWaiter() async {}

  Future<void> dispose() => updates.close();
}
