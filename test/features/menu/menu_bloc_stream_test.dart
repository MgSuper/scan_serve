import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';
import 'package:scan_serve/features/menu/domain/use_cases/get_active_menu.dart';
import 'package:scan_serve/features/menu/domain/use_cases/watch_active_menu.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_event.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_state.dart';
import 'package:scan_serve/shared/domain/audit_metadata.dart';

void main() {
  test(
    'MenuBloc reflects a menu item emitted after Angular creates it',
    () async {
      final repository = _StreamRepository();
      final bloc = MenuBloc(
        getActiveMenu: GetActiveMenu(repository),
        watchActiveMenu: WatchActiveMenu(repository),
      );
      final states = <MenuState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(
        const LoadMenu(restaurantId: 'scanserve-demo', branchId: 'main-branch'),
      );
      await Future<void>.delayed(Duration.zero);
      repository.updates.add(_catalog('dashboard-item'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        states.whereType<MenuLoaded>().last.catalog.items.single.name,
        'dashboard-item',
      );

      await subscription.cancel();
      await bloc.close();
      await repository.dispose();
    },
  );
}

class _StreamRepository implements MenuRepository {
  final updates = StreamController<MenuCatalog>.broadcast();

  @override
  Future<MenuCatalog> getActiveMenu({
    required String restaurantId,
    required String branchId,
  }) async => _catalog('initial-item');

  @override
  Stream<MenuCatalog> watchActiveMenu({
    required String restaurantId,
    required String branchId,
  }) => updates.stream;

  Future<void> dispose() => updates.close();
}

MenuCatalog _catalog(String itemName) {
  final now = DateTime.utc(2026);
  final metadata = AuditMetadata(createdAt: now, updatedAt: now);
  const restaurantId = 'scanserve-demo';
  const branchId = 'main-branch';
  const menuId = 'scanserve-demo-main-branch-menu';
  const categoryId = 'mains';
  return MenuCatalog(
    menu: Menu(
      id: menuId,
      restaurantId: restaurantId,
      branchId: branchId,
      name: 'Menu',
      isActive: true,
      metadata: metadata,
    ),
    categories: [
      Category(
        id: categoryId,
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        name: 'Mains',
        displayOrder: 0,
        isActive: true,
        metadata: metadata,
      ),
    ],
    items: [
      MenuItem(
        id: itemName,
        restaurantId: restaurantId,
        branchId: branchId,
        menuId: menuId,
        categoryId: categoryId,
        name: itemName,
        price: 100,
        displayOrder: 0,
        isAvailable: true,
        metadata: metadata,
      ),
    ],
  );
}
