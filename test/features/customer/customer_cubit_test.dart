import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';
import 'package:scan_serve/features/customer/domain/models.dart';
import 'package:scan_serve/features/customer/presentation/customer_cubit.dart';

class _Repository implements CustomerRepository {
  final item = const MenuItem(
    id: 'tea',
    category: 'Drinks',
    name: 'Tea',
    description: 'Iced tea',
    price: 20000,
  );

  @override
  Future<List<MenuItem>> getActiveMenu() async => [item];
  @override
  Stream<CustomerOrder?> getActiveOrder() async* {
    yield null;
  }

  @override
  Future<void> requestWaiter() async {}
  @override
  Future<void> requestPayment() async {}
  @override
  Future<CustomerOrder> submitOrder(List<CartLine> lines) async =>
      CustomerOrder(
        id: 'ORD-1',
        lines: lines,
        status: OrderStatus.pending,
        createdAt: DateTime(2026),
      );
}

class _OrderPermissionRepository extends _Repository {
  @override
  Stream<CustomerOrder?> getActiveOrder() => Stream<CustomerOrder?>.error(
    StateError(
      'Bad state: You do not have permission to access this restaurant.',
    ),
  );
}

void main() {
  group('CustomerCubit', () {
    blocTest<CustomerCubit, CustomerState>(
      'loads the menu when the active order stream is unauthorized',
      build: () => CustomerCubit(_OrderPermissionRepository()),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<CustomerState>()
            .having((state) => state.loading, 'loading', false)
            .having((state) => state.menu, 'menu', hasLength(1))
            .having((state) => state.order, 'order', isNull)
            .having((state) => state.message, 'message', isNull),
      ],
    );
    blocTest<CustomerCubit, CustomerState>(
      'loads the active menu',
      build: () => CustomerCubit(_Repository()),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<CustomerState>()
            .having((state) => state.loading, 'loading', false)
            .having((state) => state.menu, 'menu', hasLength(1)),
      ],
    );

    blocTest<CustomerCubit, CustomerState>(
      'adds items and submits an order',
      build: () => CustomerCubit(_Repository()),
      act: (cubit) async {
        await cubit.load();
        cubit.add(_Repository().item);
        await cubit.submitOrder();
      },
      expect: () => [
        isA<CustomerState>().having(
          (state) => state.menu,
          'menu',
          hasLength(1),
        ),
        isA<CustomerState>().having(
          (state) => state.cartQuantity,
          'cart quantity',
          1,
        ),
        isA<CustomerState>()
            .having((state) => state.order?.id, 'order id', 'ORD-1')
            .having((state) => state.cart, 'cart', isEmpty),
      ],
    );
  });
}
