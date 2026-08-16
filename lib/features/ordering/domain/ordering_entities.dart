import 'package:scan_serve/shared/domain/audit_metadata.dart';

enum OrderStatus { pending, accepted, preparing, ready, served, cancelled }

class CartItem {
  const CartItem({required this.menuItemId, required this.name, required this.unitPrice, required this.quantity, this.note, this.modifiers = const []});
  final String menuItemId; final String name; final int unitPrice; final int quantity; final String? note; final List<String> modifiers;
  int get lineTotal => unitPrice * quantity;
}
class Cart {
  const Cart({required this.id, required this.restaurantId, required this.branchId, required this.tableId, required this.tableSessionId, required this.customerSessionId, required this.items, required this.metadata});
  final String id; final String restaurantId; final String branchId; final String tableId; final String tableSessionId; final String customerSessionId; final List<CartItem> items; final AuditMetadata metadata;
  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}
class OrderItem {
  const OrderItem({required this.id, required this.orderId, required this.restaurantId, required this.branchId, required this.menuItemId, required this.categoryId, required this.name, required this.unitPrice, required this.quantity, required this.metadata, this.note, this.modifiers = const []});
  final String id; final String orderId; final String restaurantId; final String branchId; final String menuItemId; final String categoryId; final String name; final int unitPrice; final int quantity; final String? note; final List<String> modifiers; final AuditMetadata metadata;
  int get lineTotal => unitPrice * quantity;
}
class Order {
  const Order({required this.id, required this.restaurantId, required this.branchId, required this.tableId, required this.tableSessionId, required this.customerSessionId, required this.status, required this.items, required this.metadata, this.customerNote});
  final String id; final String restaurantId; final String branchId; final String tableId; final String tableSessionId; final String customerSessionId; final OrderStatus status; final List<OrderItem> items; final String? customerNote; final AuditMetadata metadata;
  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  int get total => subtotal;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}
