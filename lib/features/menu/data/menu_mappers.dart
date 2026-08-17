import 'package:scan_serve/features/menu/data/menu_dtos.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/shared/data/firestore/firestore_metadata_dto.dart';

extension MenuDtoMapper on MenuDto {
  Menu toDomain() => Menu(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    name: name,
    description: description,
    isActive: isActive,
    metadata: metadata.toDomain(),
  );
}

extension MenuMapper on Menu {
  MenuDto toDto() => MenuDto(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    name: name,
    description: description,
    isActive: isActive,
    metadata: FirestoreMetadataDto.fromDomain(metadata),
  );
}

extension CategoryDtoMapper on CategoryDto {
  Category toDomain() => Category(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    menuId: menuId,
    name: name,
    description: description,
    displayOrder: displayOrder,
    isActive: isActive,
    metadata: metadata.toDomain(),
  );
}

extension CategoryMapper on Category {
  CategoryDto toDto() => CategoryDto(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    menuId: menuId,
    name: name,
    description: description,
    displayOrder: displayOrder,
    isActive: isActive,
    metadata: FirestoreMetadataDto.fromDomain(metadata),
  );
}

extension MenuItemDtoMapper on MenuItemDto {
  MenuItem toDomain() => MenuItem(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    menuId: menuId,
    categoryId: categoryId,
    name: name,
    description: description,
    imageUrl: imageUrl,
    price: price,
    displayOrder: displayOrder,
    isAvailable: isAvailable,
    metadata: metadata.toDomain(),
  );
}

extension MenuItemMapper on MenuItem {
  MenuItemDto toDto() => MenuItemDto(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    menuId: menuId,
    categoryId: categoryId,
    name: name,
    description: description,
    imageUrl: imageUrl,
    price: price,
    displayOrder: displayOrder,
    isAvailable: isAvailable,
    metadata: FirestoreMetadataDto.fromDomain(metadata),
  );
}
