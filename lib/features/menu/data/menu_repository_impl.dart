import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:scan_serve/core/error/repository_exception.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';
import 'package:scan_serve/shared/domain/audit_metadata.dart';

class _CategoryRecord {
  const _CategoryRecord({
    required this.name,
    this.parentCategoryId,
    this.displayOrder = 0,
  });

  final String name;
  final String? parentCategoryId;
  final int displayOrder;
}

class MenuRepositoryImpl implements MenuRepository {
  const MenuRepositoryImpl({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _restaurantMenu(
    String restaurantId,
  ) =>
      _firestore.collection('restaurants').doc(restaurantId).collection('menu');

  CollectionReference<Map<String, dynamic>> _restaurantCategories(
    String restaurantId,
  ) => _firestore
      .collection('restaurants')
      .doc(restaurantId)
      .collection('categories');

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
      final categoryDocuments = await _loadCategoryDocuments(
        restaurantId: restaurantId,
        branchId: branchId,
      );
      return _catalogFromDocuments(
        snapshot.docs,
        categoryDocuments: categoryDocuments,
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
    final controller = StreamController<MenuCatalog>();
    var menuDocuments = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var categoryDocuments = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var menuReady = false;

    void emitCatalog() {
      if (!menuReady) return;
      _logSnapshot(
        path: path,
        restaurantId: restaurantId,
        branchId: branchId,
        documents: menuDocuments,
      );
      try {
        controller.add(
          _catalogFromDocuments(
            menuDocuments,
            categoryDocuments: categoryDocuments,
            restaurantId: restaurantId,
            branchId: branchId,
            allowEmpty: true,
          ),
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
        controller.addError(error, stackTrace);
      }
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    menuSubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    categorySubscription;

    menuSubscription = _restaurantMenu(restaurantId).snapshots().listen(
      (snapshot) {
        menuDocuments = snapshot.docs;
        menuReady = true;
        emitCatalog();
      },
      onError: (Object error, StackTrace stackTrace) {
        _logError(
          operation: 'watchActiveMenu stream',
          path: path,
          restaurantId: restaurantId,
          branchId: branchId,
          error: error,
          stackTrace: stackTrace,
        );
        controller.addError(error, stackTrace);
      },
    );

    categorySubscription = _restaurantCategories(restaurantId).snapshots().listen(
      (snapshot) {
        categoryDocuments = snapshot.docs;
        debugPrint(
          '[MenuRepository] category snapshot path=${_categoryPath(restaurantId)} '
          'restaurantId=$restaurantId branchId=$branchId '
          'documentCount=${snapshot.docs.length}',
        );
        emitCatalog();
      },
      onError: (Object error, StackTrace stackTrace) {
        // Customer sessions may be unable to read category documents under
        // restrictive rules. Menu-item parentCategoryId metadata remains a
        // complete fallback, so keep the menu stream usable.
        categoryDocuments = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _logError(
          operation: 'watch category stream; deriving from menu items',
          path: _categoryPath(restaurantId),
          restaurantId: restaurantId,
          branchId: branchId,
          error: error,
          stackTrace: stackTrace,
        );
        emitCatalog();
      },
    );

    controller.onCancel = () async {
      await menuSubscription.cancel();
      await categorySubscription.cancel();
    };
    return controller.stream;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _loadCategoryDocuments({
    required String restaurantId,
    required String branchId,
  }) async {
    try {
      final snapshot = await _restaurantCategories(restaurantId).get();
      debugPrint(
        '[MenuRepository] category snapshot path=${_categoryPath(restaurantId)} '
        'restaurantId=$restaurantId branchId=$branchId '
        'documentCount=${snapshot.docs.length}',
      );
      return snapshot.docs
          .where((document) {
            final data = document.data();
            final documentBranchId = _optionalString(data['branchId']);
            return documentBranchId == null || documentBranchId == branchId;
          })
          .toList(growable: false);
    } catch (error, stackTrace) {
      _logError(
        operation: 'load categories; deriving from menu items',
        path: _categoryPath(restaurantId),
        restaurantId: restaurantId,
        branchId: branchId,
        error: error,
        stackTrace: stackTrace,
      );
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  MenuCatalog _catalogFromDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categoryDocuments =
        const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
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
    final categoryRecords = <String, _CategoryRecord>{};

    // Menu item metadata remains the fallback when customer sessions cannot
    // read the staff-managed categories collection.
    for (final document in documents) {
      final data = document.data();
      final category =
          _optionalString(data['categoryName']) ??
          _optionalString(data['category']) ??
          _optionalString(data['categoryId']) ??
          'Menu';
      final categoryId =
          _optionalString(data['categoryId']) ?? _categoryId(category);
      final parentCategoryId =
          _optionalString(data['parentCategoryId']) ??
          _optionalString(data['parentId']);

      if (parentCategoryId != null &&
          !categoryRecords.containsKey(parentCategoryId)) {
        categoryRecords[parentCategoryId] = _CategoryRecord(
          name: _optionalString(data['category']) ?? parentCategoryId,
          displayOrder: categoryRecords.length,
        );
      }
      categoryRecords.putIfAbsent(
        categoryId,
        () => _CategoryRecord(
          name: category,
          parentCategoryId: parentCategoryId,
          displayOrder: categoryRecords.length,
        ),
      );
    }

    // Firestore category documents are canonical and can describe categories
    // that currently have zero items. They also repair a missing synthesized
    // parent when only a child document is present.
    for (final document in categoryDocuments) {
      final data = document.data();
      if (data['isActive'] == false ||
          data['archived'] == true ||
          data['isArchived'] == true) {
        continue;
      }
      final categoryId = _optionalString(data['id']) ?? document.id;
      final categoryName = _optionalString(data['name']);
      if (categoryName == null) continue;
      final parentCategoryId = _optionalString(data['parentCategoryId']);
      if (parentCategoryId != null &&
          !categoryRecords.containsKey(parentCategoryId)) {
        categoryRecords[parentCategoryId] = _CategoryRecord(
          name: parentCategoryId,
          displayOrder: categoryRecords.length,
        );
      }
      categoryRecords[categoryId] = _CategoryRecord(
        name: categoryName,
        parentCategoryId: parentCategoryId,
        displayOrder: _integer(data['displayOrder']) ?? categoryRecords.length,
      );
    }

    final categories = categoryRecords.entries
        .map(
          (entry) => Category(
            id: entry.key,
            restaurantId: restaurantId,
            branchId: branchId,
            menuId: menuId,
            name: entry.value.name,
            parentCategoryId: entry.value.parentCategoryId,
            displayOrder: entry.value.displayOrder,
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
        _optionalString(data['categoryName']) ??
        _optionalString(data['category']) ??
        _optionalString(data['categoryId']) ??
        'Menu';
    final categoryId =
        _optionalString(data['categoryId']) ?? _categoryId(category);
    final menuId =
        _optionalString(data['menuId']) ?? '$restaurantId-$branchId-menu';
    final resolvedBranchId = documentBranchId ?? branchId;

    return MenuItem(
      // Use the immutable Firestore document ID for downstream order lookups.
      id: document.id,
      restaurantId: documentRestaurantId ?? restaurantId,
      branchId: resolvedBranchId,
      menuId: menuId,
      categoryId: categoryId,
      name: name,
      description: _optionalString(data['description']),
      imageUrl: _optionalString(data['imageUrl']),
      categoryName: _optionalString(data['categoryName']),
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

  String _categoryPath(String restaurantId) =>
      'restaurants/$restaurantId/categories';

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
