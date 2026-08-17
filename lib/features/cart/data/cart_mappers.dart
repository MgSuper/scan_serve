import 'package:scan_serve/features/cart/data/cart_dtos.dart';
import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/shared/data/firestore/firestore_metadata_dto.dart';

extension CartItemDtoMapper on CartItemDto {
  CartItem toDomain() => CartItem(
    menuItemId: menuItemId,
    name: name,
    unitPrice: unitPrice,
    quantity: quantity,
    note: note,
    modifiers: List.unmodifiable(modifiers),
  );
}

extension CartItemMapper on CartItem {
  CartItemDto toDto() => CartItemDto(
    menuItemId: menuItemId,
    name: name,
    unitPrice: unitPrice,
    quantity: quantity,
    note: note,
    modifiers: List.unmodifiable(modifiers),
  );
}

extension CartDtoMapper on CartDto {
  Cart toDomain() => Cart(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    tableId: tableId,
    tableSessionId: tableSessionId,
    customerSessionId: customerSessionId,
    items: List.unmodifiable(items.map((item) => item.toDomain())),
    metadata: metadata.toDomain(),
  );
}

extension CartMapper on Cart {
  CartDto toDto() {
    final metadataDto = FirestoreMetadataDto.fromDomain(metadata);
    return CartDto(
      id: id,
      restaurantId: restaurantId,
      branchId: branchId,
      tableId: tableId,
      tableSessionId: tableSessionId,
      customerSessionId: customerSessionId,
      items: List.unmodifiable(items.map((item) => item.toDto())),

      metadata: metadataDto,
    );
  }
}
