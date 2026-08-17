import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scan_serve/core/error/repository_exception.dart';
import 'package:scan_serve/features/menu/data/menu_dtos.dart';
import 'package:scan_serve/features/menu/data/menu_mappers.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';
import 'package:scan_serve/shared/data/firestore/firestore_metadata_dto.dart';

class MenuRepositoryImpl implements MenuRepository {
  const MenuRepositoryImpl({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<MenuCatalog> getActiveMenu({
    required String restaurantId,
    required String branchId,
  }) async {
    try {
      final menuSnapshot = await _firestore
          .collection('menus')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      final menuDocument = menuSnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
          .firstWhere((document) {
            final data = document!.data();
            return data['restaurantId'] == restaurantId &&
                data['branchId'] == branchId;
          }, orElse: () => null);
      if (menuDocument == null) {
        throw RepositoryException(
          'No active menu is available for this restaurant branch.',
        );
      }

      final menu = _menuFromDocument(menuDocument).toDomain();
      final categorySnapshot = await _firestore
          .collection('categories')
          .where('menuId', isEqualTo: menu.id)
          .orderBy('displayOrder')
          .get();
      final categories = categorySnapshot.docs
          .map(_categoryFromDocument)
          .where(
            (category) =>
                category.restaurantId == restaurantId &&
                category.branchId == branchId &&
                category.isActive,
          )
          .map((category) => category.toDomain())
          .toList(growable: false);

      final itemSnapshots = await Future.wait(
        categories.map(
          (category) => _firestore
              .collection('menuItems')
              .where('categoryId', isEqualTo: category.id)
              .where('isAvailable', isEqualTo: true)
              .orderBy('displayOrder')
              .get(),
        ),
      );
      final items = itemSnapshots
          .expand((snapshot) => snapshot.docs)
          .map(_menuItemFromDocument)
          .where(
            (item) =>
                item.restaurantId == restaurantId &&
                item.branchId == branchId &&
                item.menuId == menu.id &&
                item.isAvailable,
          )
          .map((item) => item.toDomain())
          .toList(growable: false);

      return MenuCatalog(
        menu: menu,
        categories: List.unmodifiable(categories),
        items: List.unmodifiable(items),
      );
    } on RepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RepositoryException(_firebaseMessage(error));
    } catch (error) {
      throw RepositoryException('Unable to load the active menu.');
    }
  }

  MenuDto _menuFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return MenuDto(
      id: _string(data, 'id', fallback: document.id),
      restaurantId: _string(data, 'restaurantId'),
      branchId: _string(data, 'branchId'),
      name: _string(data, 'name'),
      description: data['description'] as String?,
      isActive: _bool(data, 'isActive'),
      metadata: FirestoreMetadataDto.fromFirestore(_metadata(data)),
    );
  }

  CategoryDto _categoryFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return CategoryDto(
      id: _string(data, 'id', fallback: document.id),
      restaurantId: _string(data, 'restaurantId'),
      branchId: _string(data, 'branchId'),
      menuId: _string(data, 'menuId'),
      name: _string(data, 'name'),
      description: data['description'] as String?,
      displayOrder: _integer(data, 'displayOrder'),
      isActive: _bool(data, 'isActive'),
      metadata: FirestoreMetadataDto.fromFirestore(_metadata(data)),
    );
  }

  MenuItemDto _menuItemFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return MenuItemDto(
      id: _string(data, 'id', fallback: document.id),
      restaurantId: _string(data, 'restaurantId'),
      branchId: _string(data, 'branchId'),
      menuId: _string(data, 'menuId'),
      categoryId: _string(data, 'categoryId'),
      name: _string(data, 'name'),
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      price: _integer(data, 'price'),
      displayOrder: _integer(data, 'displayOrder'),
      isAvailable: _bool(data, 'isAvailable'),
      metadata: FirestoreMetadataDto.fromFirestore(_metadata(data)),
    );
  }

  Map<String, Object?> _metadata(Map<String, dynamic> data) => {
    'createdAt': _date(data, 'createdAt'),
    'updatedAt': _date(data, 'updatedAt'),
    'submittedAt': _optionalDate(data, 'submittedAt'),
    'acceptedAt': _optionalDate(data, 'acceptedAt'),
    'preparedAt': _optionalDate(data, 'preparedAt'),
    'servedAt': _optionalDate(data, 'servedAt'),
    'deletedAt': _optionalDate(data, 'deletedAt'),
    'deletedBy': data['deletedBy'] as String?,
    'isArchived': data['isArchived'] as bool? ?? false,
  };

  String _string(Map<String, dynamic> data, String key, {String? fallback}) {
    final value = data[key] ?? fallback;
    if (value is! String || value.trim().isEmpty) {
      throw RepositoryException('Menu data is missing a valid $key field.');
    }
    return value;
  }

  bool _bool(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! bool) {
      throw RepositoryException('Menu data is missing a valid $key field.');
    }
    return value;
  }

  int _integer(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! num || !value.isFinite || value % 1 != 0) {
      throw RepositoryException('Menu data is missing a valid $key field.');
    }
    return value.toInt();
  }

  DateTime _date(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    throw RepositoryException('Menu data is missing a valid $key timestamp.');
  }

  DateTime? _optionalDate(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    throw RepositoryException('Menu data contains an invalid $key timestamp.');
  }

  String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to view this menu.';
      case 'unavailable':
        return 'The menu is temporarily unavailable. Please try again.';
      default:
        return 'Unable to load the active menu.';
    }
  }
}
