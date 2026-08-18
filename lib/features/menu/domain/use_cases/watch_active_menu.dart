import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';

class WatchActiveMenu {
  const WatchActiveMenu(this._repository);

  final MenuRepository _repository;

  Stream<MenuCatalog> call({
    required String restaurantId,
    required String branchId,
  }) => _repository.watchActiveMenu(
    restaurantId: restaurantId,
    branchId: branchId,
  );
}
