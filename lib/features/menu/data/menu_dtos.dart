import 'package:scan_serve/shared/data/firestore/firestore_metadata_dto.dart';

class MenuDto {
  const MenuDto({required this.id, required this.restaurantId, required this.branchId, required this.name, required this.isActive, required this.metadata, this.description});
  final String id; final String restaurantId; final String branchId; final String name; final String? description; final bool isActive; final FirestoreMetadataDto metadata;
}
class CategoryDto {
  const CategoryDto({required this.id, required this.restaurantId, required this.branchId, required this.menuId, required this.name, required this.displayOrder, required this.isActive, required this.metadata, this.description});
  final String id; final String restaurantId; final String branchId; final String menuId; final String name; final String? description; final int displayOrder; final bool isActive; final FirestoreMetadataDto metadata;
}
class MenuItemDto {
  const MenuItemDto({required this.id, required this.restaurantId, required this.branchId, required this.menuId, required this.categoryId, required this.name, required this.price, required this.displayOrder, required this.isAvailable, required this.metadata, this.description, this.imageUrl});
  final String id; final String restaurantId; final String branchId; final String menuId; final String categoryId; final String name; final String? description; final String? imageUrl; final int price; final int displayOrder; final bool isAvailable; final FirestoreMetadataDto metadata;
}
