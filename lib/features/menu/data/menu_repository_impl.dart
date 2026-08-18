import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:scan_serve/core/error/repository_exception.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';
import 'package:scan_serve/shared/domain/audit_metadata.dart';

class MenuRepositoryImpl implements MenuRepository {
  const MenuRepositoryImpl({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _restaurantMenu(
    String restaurantId,
  ) =>
      _firestore.collection('restaurants').doc(restaurantId).collection('menu');

  @override
  Future<MenuCatalog> getActiveMenu({
    required String restaurantId,
    required String branchId,
  }) async {
    try {
      final snapshot = await _restaurantMenu(restaurantId).get();
      _logSnapshot(
        path: _menuPath(restaurantId),
        restaurantId: restaurantId,
        branchId: branchId,
        documents: snapshot.docs,
      );
      return _catalogFromDocuments(
        snapshot.docs,
        restaurantId: restaurantId,
        branchId: branchId,
        allowEmpty: true,
      );
    } on RepositoryException catch (error, stackTrace) {
      _logError(
        operation: 'getActiveMenu',
        path: _menuPath(restaurantId),
        restaurantId: restaurantId,
        branchId: branchId,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      _logError(
        operation: 'getActiveMenu',
        path: _menuPath(restaurantId),
        restaurantId: restaurantId,
        branchId: branchId,
        error: error,
        stackTrace: stackTrace,
      );
      throw RepositoryException(_firebaseMessage(error));
    } catch (error, stackTrace) {
      _logError(
        operation: 'getActiveMenu',
        path: _menuPath(restaurantId),
        restaurantId: restaurantId,
        branchId: branchId,
        error: error,
        stackTrace: stackTrace,
      );
      throw RepositoryException('Unable to load the active menu.');
    }
  }

  @override
  Stream<MenuCatalog> watchActiveMenu({
    required String restaurantId,
    required String branchId,
  }) {
    final path = _menuPath(restaurantId);
    return _restaurantMenu(restaurantId)
        .snapshots()
        .map((snapshot) {
          _logSnapshot(
            path: path,
            restaurantId: restaurantId,
            branchId: branchId,
            documents: snapshot.docs,
          );
          try {
            return _catalogFromDocuments(
              snapshot.docs,
              restaurantId: restaurantId,
              branchId: branchId,
              allowEmpty: true,
            );
          } catch (error, stackTrace) {
            _logError(
              operation: 'watchActiveMenu mapping',
              path: path,
              restaurantId: restaurantId,
              branchId: branchId,
              error: error,
              stackTrace: stackTrace,
            );
            rethrow;
          }
        })
        .handleError((Object error, StackTrace stackTrace) {
          _logError(
            operation: 'watchActiveMenu stream',
            path: path,
            restaurantId: restaurantId,
            branchId: branchId,
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  MenuCatalog _catalogFromDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    required String restaurantId,
    required String branchId,
    bool allowEmpty = false,
  }) {
    final items = <MenuItem>[];
    for (var index = 0; index < documents.length; index += 1) {
      final item = _menuItemFromDocument(
        documents[index],
        restaurantId: restaurantId,
        branchId: branchId,
        displayOrder: index,
      );
      if (item != null) items.add(item);
    }

    if (items.isEmpty && !allowEmpty) {
      throw RepositoryException(
        'No active menu items are available for this restaurant branch.',
      );
    }

    final menuId = items.isEmpty
        ? '$restaurantId-$branchId-menu'
        : items.first.menuId;
    final now = DateTime.now().toUtc();
    final metadata = AuditMetadata(createdAt: now, updatedAt: now);
    final categoryNames = <String, String>{};
    for (final document in documents) {
      final data = document.data();
      final category =
          _optionalString(data['category']) ??
          _optionalString(data['categoryId']) ??
          'Menu';
      categoryNames.putIfAbsent(_categoryId(category), () => category);
    }

    final categories = categoryNames.entries
        .map(
          (entry) => Category(
            id: entry.key,
            restaurantId: restaurantId,
            branchId: branchId,
            menuId: menuId,
            name: entry.value,
            displayOrder: categoryNames.keys.toList().indexOf(entry.key),
            isActive: true,
            metadata: metadata,
          ),
        )
        .toList(growable: false);

    return MenuCatalog(
      menu: Menu(
        id: menuId,
        restaurantId: restaurantId,
        branchId: branchId,
        name: 'Menu',
        isActive: true,
        metadata: metadata,
      ),
      categories: List.unmodifiable(categories),
      items: List.unmodifiable(items),
    );
  }

  MenuItem? _menuItemFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    required String restaurantId,
    required String branchId,
    required int displayOrder,
  }) {
    final data = document.data();
    final documentRestaurantId = _optionalString(data['restaurantId']);
    if (documentRestaurantId != null && documentRestaurantId != restaurantId) {
      return null;
    }

    final documentBranchId = _optionalString(data['branchId']);
    if (documentBranchId != null && documentBranchId != branchId) {
      return null;
    }

    if (data['archived'] == true || data['isArchived'] == true) return null;

    final name = _optionalString(data['name']);
    final price = data['price'];
    if (name == null || price is! num || !price.isFinite || price < 0) {
      return null;
    }

    final availability = data['isAvailable'];
    final available = availability is bool
        ? availability
        : switch (data['availability'] ?? data['status']) {
            'out_of_stock' => false,
            'in_stock' => true,
            _ => true,
          };
    if (!available) return null;

    final category =
        _optionalString(data['category']) ??
        _optionalString(data['categoryId']) ??
        'Menu';
    final categoryId =
        _optionalString(data['categoryId']) ?? _categoryId(category);
    final menuId =
        _optionalString(data['menuId']) ?? '$restaurantId-$branchId-menu';
    final resolvedBranchId = documentBranchId ?? branchId;

    return MenuItem(
      id: _optionalString(data['id']) ?? document.id,
      restaurantId: documentRestaurantId ?? restaurantId,
      branchId: resolvedBranchId,
      menuId: menuId,
      categoryId: categoryId,
      name: name,
      description: _optionalString(data['description']),
      imageUrl: _optionalString(data['imageUrl']),
      price: price.toInt(),
      displayOrder: _integer(data['displayOrder']) ?? displayOrder,
      isAvailable: true,
      metadata: _metadata(data),
    );
  }

  AuditMetadata _metadata(Map<String, dynamic> data) {
    final now = DateTime.now().toUtc();
    return AuditMetadata(
      createdAt: _date(data['createdAt']) ?? now,
      updatedAt: _date(data['updatedAt']) ?? now,
      isArchived: data['archived'] == true || data['isArchived'] == true,
    );
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    return null;
  }

  int? _integer(Object? value) {
    if (value is num && value.isFinite && value >= 0) return value.toInt();
    return null;
  }

  String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  String _categoryId(String category) {
    final normalized = category.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    return normalized
        .replaceFirst(RegExp(r'^-+'), '')
        .replaceFirst(RegExp(r'-+$'), '');
  }

  String _menuPath(String restaurantId) => 'restaurants/$restaurantId/menu';

  void _logSnapshot({
    required String path,
    required String restaurantId,
    required String branchId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  }) {
    final documentPaths = documents
        .map((document) => document.reference.path)
        .join(', ');
    debugPrint(
      '[MenuRepository] snapshot path=$path '
      'restaurantId=$restaurantId branchId=$branchId '
      'documentCount=${documents.length} documentPaths=[$documentPaths]',
    );
  }

  void _logError({
    required String operation,
    required String path,
    required String restaurantId,
    required String branchId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint(
      '[MenuRepository] $operation failed '
      'path=$path restaurantId=$restaurantId branchId=$branchId '
      'error=$error\n$stackTrace',
    );
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
