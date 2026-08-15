import 'package:equatable/equatable.dart';

enum OrderStatus { pending, accepted, preparing, ready, served }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Order received',
    OrderStatus.accepted => 'Accepted by kitchen',
    OrderStatus.preparing => 'Being prepared',
    OrderStatus.ready => 'Ready for pickup',
    OrderStatus.served => 'Served',
  };
}

class MenuItem extends Equatable {
  const MenuItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.price,
    this.available = true,
  });

  final String id;
  final String category;
  final String name;
  final String description;
  final int price;
  final bool available;

  @override
  List<Object> get props => [id, category, name, description, price, available];
}

class CartLine extends Equatable {
  const CartLine({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  int get total => item.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(item: item, quantity: quantity ?? this.quantity);

  @override
  List<Object> get props => [item, quantity];
}

class CustomerOrder extends Equatable {
  const CustomerOrder({
    required this.id,
    required this.lines,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final List<CartLine> lines;
  final OrderStatus status;
  final DateTime createdAt;

  int get total => lines.fold(0, (sum, line) => sum + line.total);

  @override
  List<Object> get props => [id, lines, status, createdAt];
}
