import 'package:scan_serve/shared/data/firestore/firestore_metadata_dto.dart';

class CartItemDto {
  const CartItemDto({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.notes,
    this.note,
    this.modifiers = const [],
  });

  final String menuItemId;
  final String name;
  final int unitPrice;
  final int quantity;
  final String? notes;
  final String? note;
  final List<String> modifiers;
}

class CartDto {
  const CartDto({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.tableId,
    required this.tableSessionId,
    required this.customerSessionId,
    required this.items,
    required this.metadata,
  });

  final String id;
  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;
  final List<CartItemDto> items;
  final FirestoreMetadataDto metadata;
}

class OrderItemDto {
  const OrderItemDto({
    required this.id,
    required this.orderId,
    required this.restaurantId,
    required this.branchId,
    required this.menuItemId,
    required this.categoryId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.metadata,
    this.categoryName,
    this.imageUrl,
    this.notes,
    this.note,
    this.modifiers = const [],
  });

  final String id;
  final String orderId;
  final String restaurantId;
  final String branchId;
  final String menuItemId;
  final String categoryId;
  final String? categoryName;
  final String? imageUrl;
  final String name;
  final int unitPrice;
  final int quantity;
  final String? notes;
  final String? note;
  final List<String> modifiers;
  final FirestoreMetadataDto metadata;
}

class OrderDto {
  const OrderDto({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.tableId,
    required this.tableSessionId,
    required this.customerSessionId,
    required this.status,
    required this.items,
    required this.metadata,
    this.customerNote,
  });

  final String id;
  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;
  final String status;
  final List<OrderItemDto> items;
  final String? customerNote;
  final FirestoreMetadataDto metadata;
}
