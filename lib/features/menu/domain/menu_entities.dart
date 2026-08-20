import 'package:scan_serve/shared/domain/audit_metadata.dart';

class Menu {
  const Menu({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.name,
    required this.isActive,
    required this.metadata,
    this.description,
  });
  final String id;
  final String restaurantId;
  final String branchId;
  final String name;
  final String? description;
  final bool isActive;
  final AuditMetadata metadata;
}

class Category {
  const Category({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.menuId,
    required this.name,
    required this.displayOrder,
    required this.isActive,
    required this.metadata,
    this.description,
  });
  final String id;
  final String restaurantId;
  final String branchId;
  final String menuId;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final AuditMetadata metadata;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.menuId,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.displayOrder,
    required this.isAvailable,
    required this.metadata,
    this.description,
    this.imageUrl,
    this.categoryName,
  });
  final String id;
  final String restaurantId;
  final String branchId;
  final String menuId;
  final String categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? categoryName;
  final int price;
  final int displayOrder;
  final bool isAvailable;
  final AuditMetadata metadata;
}

class MenuCatalog {
  const MenuCatalog({
    required this.menu,
    required this.categories,
    required this.items,
  });

  final Menu menu;
  final List<Category> categories;
  final List<MenuItem> items;
}
