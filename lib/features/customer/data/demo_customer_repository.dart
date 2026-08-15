import '../domain/customer_repository.dart';
import '../domain/models.dart';

/// Local development implementation of the customer contract.
/// Replace with a Firestore/Cloud Functions adapter without changing UI or domain code.
class DemoCustomerRepository implements CustomerRepository {
  CustomerOrder? _activeOrder;

  static const _menu = <MenuItem>[
    MenuItem(id: 'pho-bo', category: 'Mains', name: 'Phở bò', description: 'Slow-simmered beef noodle soup', price: 85000),
    MenuItem(id: 'bun-cha', category: 'Mains', name: 'Bún chả', description: 'Grilled pork with rice noodles', price: 79000),
    MenuItem(id: 'spring-rolls', category: 'Starters', name: 'Fresh spring rolls', description: 'Herbs, prawns, and peanut sauce', price: 55000),
    MenuItem(id: 'iced-coffee', category: 'Drinks', name: 'Vietnamese iced coffee', description: 'Robusta coffee with condensed milk', price: 35000),
    MenuItem(id: 'lime-soda', category: 'Drinks', name: 'Lime soda', description: 'Fresh lime and sparkling water', price: 30000),
  ];

  @override
  Future<List<MenuItem>> getActiveMenu() async => _menu;

  @override
  Future<CustomerOrder?> getActiveOrder() async => _activeOrder;

  @override
  Future<void> requestWaiter() async {}

  @override
  Future<CustomerOrder> submitOrder(List<CartLine> lines) async {
    if (lines.isEmpty) throw StateError('Your cart is empty.');
    _activeOrder = CustomerOrder(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      lines: List.unmodifiable(lines),
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    return _activeOrder!;
  }
}
