import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/domain/repositories/cart_repository.dart';
import 'package:scan_serve/features/cart/domain/use_cases/add_to_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/remove_from_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/submit_order_use_case.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';
import 'package:scan_serve/features/menu/domain/use_cases/get_active_menu.dart';
import 'package:scan_serve/features/menu/domain/use_cases/watch_active_menu.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:scan_serve/features/menu/presentation/pages/menu_page.dart';
import 'package:scan_serve/shared/domain/audit_metadata.dart';

void main() {
  testWidgets('filters menu items by name as the user searches', (
    tester,
  ) async {
    final menuRepository = _MenuRepository(_catalog);
    final cartRepository = _CartRepository();
    final menuBloc = MenuBloc(
      getActiveMenu: GetActiveMenu(menuRepository),
      watchActiveMenu: WatchActiveMenu(menuRepository),
    );
    final cartBloc = CartBloc(
      addToCart: AddToCart(cartRepository),
      removeFromCart: RemoveFromCart(cartRepository),
      submitOrder: SubmitOrderUseCase(cartRepository),
      initialState: CartInitial(
        Cart.empty(
          id: 'cart_active-customer-session',
          restaurantId: 'scanserve-demo',
          branchId: 'main-branch',
          tableId: 'table-12',
          tableSessionId: 'active-table-session',
          customerSessionId: 'active-customer-session',
        ),
      ),
    );
    addTearDown(() async {
      await menuBloc.close();
      await cartBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: menuBloc),
            BlocProvider.value(value: cartBloc),
          ],
          child: const MenuPage(
            restaurantId: 'scanserve-demo',
            branchId: 'main-branch',
            tableId: 'table-12',
            tableSessionId: 'active-table-session',
            customerSessionId: 'active-customer-session',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Spicy Noodles'), findsOneWidget);
    expect(find.text('Fruit Yogurt'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'yogurt');
    await tester.pump();

    expect(find.text('Fruit Yogurt'), findsOneWidget);
    expect(find.text('Spicy Noodles'), findsNothing);
  });

  testWidgets('filters menu items from the category drawer', (tester) async {
    final menuRepository = _MenuRepository(_catalog);
    final cartRepository = _CartRepository();
    final menuBloc = MenuBloc(
      getActiveMenu: GetActiveMenu(menuRepository),
      watchActiveMenu: WatchActiveMenu(menuRepository),
    );
    final cartBloc = CartBloc(
      addToCart: AddToCart(cartRepository),
      removeFromCart: RemoveFromCart(cartRepository),
      submitOrder: SubmitOrderUseCase(cartRepository),
      initialState: CartInitial(
        Cart.empty(
          id: 'cart_active-customer-session',
          restaurantId: 'scanserve-demo',
          branchId: 'main-branch',
          tableId: 'table-12',
          tableSessionId: 'active-table-session',
          customerSessionId: 'active-customer-session',
        ),
      ),
    );
    addTearDown(() async {
      await menuBloc.close();
      await cartBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: menuBloc),
            BlocProvider.value(value: cartBloc),
          ],
          child: const MenuPage(
            restaurantId: 'scanserve-demo',
            branchId: 'main-branch',
            tableId: 'table-12',
            tableSessionId: 'active-table-session',
            customerSessionId: 'active-customer-session',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Browse by category'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Desserts')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fruit Yogurt'), findsOneWidget);
    expect(find.text('Spicy Noodles'), findsNothing);
  });
}

final _catalog = _createCatalog();

MenuCatalog _createCatalog() {
  final now = DateTime.utc(2026);
  final metadata = AuditMetadata(createdAt: now, updatedAt: now);
  const restaurantId = 'scanserve-demo';
  const branchId = 'main-branch';
  const menuId = 'scanserve-demo-main-branch-menu';
  return MenuCatalog(
    menu: Menu(
      id: menuId,
      restaurantId: restaurantId,
      branchId: branchId,
      name: 'Customer menu',
      isActive: true,
      metadata: metadata,
    ),
    categories: [
      Category(
        id: 'mains',
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        name: 'Mains',
        displayOrder: 0,
        isActive: true,
        metadata: metadata,
      ),
      Category(
        id: 'desserts',
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        name: 'Desserts',
        displayOrder: 1,
        isActive: true,
        metadata: metadata,
      ),
    ],
    items: [
      MenuItem(
        id: 'spicy-noodles',
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        categoryId: 'mains',
        categoryName: 'Mains',
        name: 'Spicy Noodles',
        description: 'Chilli and garlic noodles',
        imageUrl: 'https://example.invalid/spicy-noodles.png',
        price: 72000,
        displayOrder: 0,
        isAvailable: true,
        metadata: metadata,
      ),
      MenuItem(
        id: 'fruit-yogurt',
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        categoryId: 'desserts',
        categoryName: 'Desserts',
        name: 'Fruit Yogurt',
        description: 'Yogurt with tropical fruit',
        price: 42000,
        displayOrder: 1,
        isAvailable: true,
        metadata: metadata,
      ),
    ],
  );
}

class _MenuRepository implements MenuRepository {
  _MenuRepository(this.catalog);

  final MenuCatalog catalog;

  @override
  Future<MenuCatalog> getActiveMenu({
    required String restaurantId,
    required String branchId,
  }) async => catalog;

  @override
  Stream<MenuCatalog> watchActiveMenu({
    required String restaurantId,
    required String branchId,
  }) => Stream.value(catalog);
}

class _CartRepository implements CartRepository {
  @override
  Future<Cart> saveCart(Cart cart) async => cart;

  @override
  Future<String> submitOrder(Cart cart) async => 'order-test';
}
