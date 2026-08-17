import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';

class GetActiveMenu {
  const GetActiveMenu(this._repository);

  final MenuRepository _repository;

  Future<MenuCatalog> call({
    required String restaurantId,
    required String branchId,
  }) {
    return _repository.getActiveMenu(
      restaurantId: restaurantId,
      branchId: branchId,
    );
  }
}
