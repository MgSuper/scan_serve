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
    final fixture = await _pumpMenuPage(tester);

    expect(find.text('Spicy Noodles'), findsAtLeastNWidgets(1));
    expect(find.text('Fruit Yogurt'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'yogurt');
    await tester.pump();

    expect(find.text('Fruit Yogurt'), findsOneWidget);
    expect(find.text('Spicy Noodles'), findsNothing);
    expect(fixture.menuBloc.state.searchQuery, 'yogurt');
  });

  testWidgets('shows count badges and expands nested category children', (
    tester,
  ) async {
    await _pumpMenuPage(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final drawer = find.byType(Drawer);
    expect(
      find.descendant(of: drawer, matching: find.text('All categories')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Mains')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Desserts')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.byIcon(Icons.expand_more)),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.text('Seasonal Desserts')),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: drawer, matching: find.text('Spicy Noodles')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('Soups')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.text('1')),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(
      find.descendant(of: drawer, matching: find.text('Spicy Noodles')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spicy Noodles'), findsAtLeastNWidgets(1));
    expect(find.text('Fruit Yogurt'), findsNothing);
    expect(find.text('Phở bò'), findsNothing);
  });

  testWidgets('shows add feedback and quantity on the dish action', (
    tester,
  ) async {
    await _pumpMenuPage(tester);

    await tester.tap(find.byTooltip('Add to order').first);
    await tester.pump();

    expect(find.text('Added Spicy Noodles to order'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('keeps filters and cart state when the bottom sheet closes', (
    tester,
  ) async {
    final fixture = await _pumpMenuPage(tester);

    await tester.enterText(find.byType(TextField), 'yogurt');
    await tester.pump();
    await tester.tap(find.byTooltip('Add to order'));
    await tester.pump();

    await tester.tap(find.byTooltip('View order').first);
    await tester.pumpAndSettle();

    expect(find.text('Your order'), findsOneWidget);
    expect(find.text('Fruit Yogurt'), findsAtLeastNWidgets(1));
    expect(find.text('1 × 42000'), findsOneWidget);

    Navigator.of(tester.element(find.text('Your order'))).pop();
    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.controller?.text, 'yogurt');
    expect(fixture.menuBloc.state.searchQuery, 'yogurt');
    expect(find.text('Fruit Yogurt'), findsOneWidget);
    expect(find.text('Spicy Noodles'), findsNothing);
  });
}

Future<_MenuFixture> _pumpMenuPage(WidgetTester tester) async {
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
  return _MenuFixture(menuBloc: menuBloc, cartBloc: cartBloc);
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
        id: 'mains-spicy-noodles',
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        name: 'Spicy Noodles',
        parentCategoryId: 'mains',
        displayOrder: 0,
        isActive: true,
        metadata: metadata,
      ),
      Category(
        id: 'mains-soups',
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        name: 'Soups',
        parentCategoryId: 'mains',
        displayOrder: 1,
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
        categoryId: 'mains-spicy-noodles',
        categoryName: 'Spicy Noodles',
        name: 'Spicy Noodles',
        description: 'Chilli and garlic noodles',
        imageUrl: 'https://example.invalid/spicy-noodles.png',
        price: 72000,
        displayOrder: 0,
        isAvailable: true,
        metadata: metadata,
      ),
      MenuItem(
        id: 'pho-bo',
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        categoryId: 'mains-soups',
        categoryName: 'Soups',
        name: 'Phở bò',
        description: 'Slow-simmered beef noodle soup',
        price: 85000,
        displayOrder: 1,
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
        displayOrder: 2,
        isAvailable: true,
        metadata: metadata,
      ),
    ],
  );
}

class _MenuFixture {
  const _MenuFixture({required this.menuBloc, required this.cartBloc});

  final MenuBloc menuBloc;
  final CartBloc cartBloc;
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
