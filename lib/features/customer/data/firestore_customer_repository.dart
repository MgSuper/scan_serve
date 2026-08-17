import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/customer_repository.dart';
import '../domain/models.dart';

class FirestoreCustomerRepository implements CustomerRepository {
  FirestoreCustomerRepository({
    required FirebaseFirestore firestore,
    required this.restaurantId,
    required this.tableId,
    this.branchId = 'main-branch',
    this.tableSessionId = 'active-table-session',
    this.customerSessionId = 'active-customer-session',
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore
      .collection('restaurants')
      .doc(restaurantId)
      .collection('orders');

  @override
  Future<List<MenuItem>> getActiveMenu() async {
    try {
      final snapshot = await _firestore
          .collection('menuItems')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      return snapshot.docs
          .map(_menuItemFromDocument)
          .where((item) => item != null && item.available)
          .cast<MenuItem>()
          .toList(growable: false);
    } on FirebaseException catch (error) {
      throw StateError(
        _firebaseMessage(error, fallback: 'Unable to load the menu.'),
      );
    }
  }

  @override
  Stream<CustomerOrder?> getActiveOrder() {
    return _orders
        .where('tableId', isEqualTo: tableId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map(_orderFromDocument)
              .whereType<CustomerOrder>()
              .where((order) => _isActive(order.status))
              .toList(growable: false);
          if (orders.isEmpty) return null;
          orders.sort(
            (left, right) => right.createdAt.compareTo(left.createdAt),
          );
          return orders.first;
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            throw StateError(
              _firebaseMessage(
                error,
                fallback: 'Unable to sync the active order.',
              ),
            );
          }
          throw StateError('Unable to sync the active order.');
        });
  }

  @override
  Future<CustomerOrder> submitOrder(List<CartLine> lines) async {
    if (lines.isEmpty) throw StateError('Your cart is empty.');

    final orderReference = _orders.doc();
    final now = DateTime.now();
    final totalAmount = lines.fold<int>(
      0,
      (subtotal, line) => subtotal + line.total,
    );
    final payload = <String, Object?>{
      'id': orderReference.id,
      'restaurantId': restaurantId,
      'branchId': branchId,
      'tableId': tableId,
      'tableSessionId': tableSessionId,
      'customerSessionId': customerSessionId,
      'items': lines.map(_lineToFirestore).toList(growable: false),
      'status': 'PENDING',
      'totalAmount': totalAmount,
      'totalQuantity': lines.fold<int>(
        0,
        (quantity, line) => quantity + line.quantity,
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await orderReference.set(payload);
      return CustomerOrder(
        id: orderReference.id,
        lines: List.unmodifiable(lines),
        status: OrderStatus.pending,
        createdAt: now,
      );
    } on FirebaseException catch (error) {
      throw StateError(
        _firebaseMessage(error, fallback: 'Unable to submit the order.'),
      );
    }
  }

  @override
  Future<void> requestWaiter() async {
    final requestReference = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('waiterRequests')
        .doc();
    try {
      await requestReference.set(<String, Object?>{
        'id': requestReference.id,
        'restaurantId': restaurantId,
        'tableId': tableId,
        'tableSessionId': tableSessionId,
        'customerSessionId': customerSessionId,
        'status': 'OPEN',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw StateError(
        _firebaseMessage(error, fallback: 'Unable to notify a waiter.'),
      );
    }
  }

  Map<String, Object?> _lineToFirestore(CartLine line) => <String, Object?>{
    'itemId': line.item.id,
    'name': line.item.name,
    'description': line.item.description,
    'category': line.item.category,
    'unitPrice': line.item.price,
    'quantity': line.quantity,
    'lineTotal': line.total,
  };

  MenuItem? _menuItemFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data['branchId'] != null && data['branchId'] != branchId) return null;
    final name = data['name'];
    final price = data['price'];
    if (name is! String || price is! num) return null;
    return MenuItem(
      id: data['id'] as String? ?? document.id,
      category:
          data['category'] as String? ??
          data['categoryId'] as String? ??
          'Menu',
      name: name,
      description: data['description'] as String? ?? '',
      price: price.toInt(),
      available: data['isAvailable'] as bool? ?? false,
    );
  }

  CustomerOrder? _orderFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final status = _orderStatus(data['status']);
    final lines = _linesFromFirestore(data['items'] ?? data['lines']);
    if (status == null || lines.isEmpty) return null;
    return CustomerOrder(
      id: data['id'] as String? ?? document.id,
      lines: List.unmodifiable(lines),
      status: status,
      createdAt: _dateFromFirestore(data['createdAt']) ?? DateTime.now(),
    );
  }

  List<CartLine> _linesFromFirestore(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map((line) {
          final itemId = line['itemId'] ?? line['id'];
          final name = line['name'];
          final price = line['unitPrice'] ?? line['price'];
          final quantity = line['quantity'];
          if (itemId is! String ||
              name is! String ||
              price is! num ||
              quantity is! num) {
            return null;
          }
          return CartLine(
            item: MenuItem(
              id: itemId,
              category: line['category'] as String? ?? 'Menu',
              name: name,
              description: line['description'] as String? ?? '',
              price: price.toInt(),
            ),
            quantity: quantity.toInt(),
          );
        })
        .whereType<CartLine>()
        .toList(growable: false);
  }

  OrderStatus? _orderStatus(Object? value) => switch (value) {
    'PENDING' => OrderStatus.pending,
    'ACCEPTED' => OrderStatus.accepted,
    'PREPARING' => OrderStatus.preparing,
    'READY' => OrderStatus.ready,
    'SERVED' => OrderStatus.served,
    _ => null,
  };

  bool _isActive(OrderStatus status) => status != OrderStatus.served;

  DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _firebaseMessage(FirebaseException error, {required String fallback}) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to access this restaurant.',
      'unavailable' => 'Firebase is temporarily unavailable. Please try again.',
      _ => fallback,
    };
  }
}
