import 'package:scan_serve/shared/domain/audit_metadata.dart';

class CartItem {
  const CartItem({
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

  int get lineTotal => unitPrice * quantity;

  CartItem copyWith({
    String? name,
    int? unitPrice,
    int? quantity,
    String? note,
    List<String>? modifiers,
  }) {
    return CartItem(
      menuItemId: menuItemId,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      modifiers: List.unmodifiable(modifiers ?? this.modifiers),
    );
  }
}

class Cart {
  factory Cart.empty({
    required String id,
    required String restaurantId,
    required String branchId,
    required String tableId,
    required String tableSessionId,
    required String customerSessionId,
  }) {
    final now = DateTime.now().toUtc();
    return Cart(
      id: id,
      restaurantId: restaurantId,
      branchId: branchId,
      tableId: tableId,
      tableSessionId: tableSessionId,
      customerSessionId: customerSessionId,
      items: const <CartItem>[],
      metadata: AuditMetadata(createdAt: now, updatedAt: now),
    );
  }

  Cart({
    required this.id,
    required this.restaurantId,
    required this.branchId,
    required this.tableId,
    required this.tableSessionId,
    required this.customerSessionId,
    required List<CartItem> items,
    required this.metadata,
  }) : items = List.unmodifiable(items);

  final String id;
  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;
  final List<CartItem> items;
  final AuditMetadata metadata;

  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  Cart copyWith({List<CartItem>? items}) {
    return Cart(
      id: id,
      restaurantId: restaurantId,
      branchId: branchId,
      tableId: tableId,
      tableSessionId: tableSessionId,
      customerSessionId: customerSessionId,
      items: items ?? this.items,
      metadata: metadata,
    );
  }
}
