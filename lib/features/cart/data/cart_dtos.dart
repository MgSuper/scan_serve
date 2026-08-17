import 'package:scan_serve/shared/data/firestore/firestore_metadata_dto.dart';

class CartItemDto {
  const CartItemDto({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.note,
    this.modifiers = const <String>[],
  });

  final String menuItemId;
  final String name;
  final int unitPrice;
  final int quantity;
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
