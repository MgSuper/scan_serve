import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/domain/repositories/cart_repository.dart';
import 'package:scan_serve/features/cart/domain/use_cases/add_to_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/remove_from_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/submit_order_use_case.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';
import 'package:scan_serve/features/cart/presentation/pages/cart_page.dart';

void main() {
  testWidgets('track order closes the sheet before navigating', (tester) async {
    final cartBloc = CartBloc(
      addToCart: AddToCart(_CartRepository()),
      removeFromCart: RemoveFromCart(_CartRepository()),
      submitOrder: SubmitOrderUseCase(_CartRepository()),
      initialState: CartSubmitted(
        Cart.empty(
          id: 'cart-test',
          restaurantId: 'scanserve-demo',
          branchId: 'main-branch',
          tableId: 'table-12',
          tableSessionId: 'active-table-session',
          customerSessionId: 'active-customer-session',
        ),
        orderId: 'order-test',
      ),
    );
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/menu',
      routes: [
        GoRoute(
          path: '/menu',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BlocProvider.value(
                    value: cartBloc,
                    child: const CartSheet(),
                  ),
                ),
                child: const Text('Open cart'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/order-tracking',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Order tracking'))),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await cartBloc.close();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open cart'));
    await tester.pumpAndSettle();

    expect(find.text('Track order'), findsOneWidget);
    await tester.tap(find.text('Track order'));
    await tester.pumpAndSettle();

    expect(find.text('Order tracking'), findsOneWidget);
    expect(find.text('Your order'), findsNothing);
  });
}

class _CartRepository implements CartRepository {
  @override
  Future<Cart> saveCart(Cart cart) async => cart;

  @override
  Future<String> submitOrder(Cart cart) async => 'order-test';
}
