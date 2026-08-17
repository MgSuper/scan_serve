import 'package:scan_serve/features/menu/domain/menu_entities.dart';

abstract interface class MenuRepository {
  Future<MenuCatalog> getActiveMenu({
    required String restaurantId,
    required String branchId,
  });
}
