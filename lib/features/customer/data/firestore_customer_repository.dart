import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/customer_repository.dart';
import '../domain/models.dart';

class FirestoreCustomerRepository implements CustomerRepository {
  FirestoreCustomerRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required this.restaurantId,
    required this.tableId,
    this.branchId = 'main-branch',
    this.tableSessionId = 'active-table-session',
    this.customerSessionId = 'active-customer-session',
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;

  static const _defaultMenu = <MenuItem>[
    MenuItem(
      id: 'default-pho-bo',
      category: 'Mains',
      name: 'Phở bò',
      description: 'Slow-simmered beef noodle soup',
      price: 85000,
    ),
    MenuItem(
      id: 'default-bun-cha',
      category: 'Mains',
      name: 'Bún chả',
      description: 'Grilled pork with rice noodles',
      price: 79000,
    ),
    MenuItem(
      id: 'default-spring-rolls',
      category: 'Starters',
      name: 'Spring rolls',
      description: 'Fresh herbs, prawns, and peanut sauce',
      price: 55000,
    ),
    MenuItem(
      id: 'default-iced-coffee',
      category: 'Drinks',
      name: 'Iced coffee',
      description: 'Robusta coffee with condensed milk',
      price: 35000,
    ),
    MenuItem(
      id: 'default-lime-soda',
      category: 'Drinks',
      name: 'Lime soda',
      description: 'Fresh lime and sparkling water',
      price: 30000,
    ),
  ];

  CollectionReference<Map<String, dynamic>> get _menu =>
      _firestore.collection('restaurants').doc(restaurantId).collection('menu');

  CollectionReference<Map<String, dynamic>> get _orders => _firestore
      .collection('restaurants')
      .doc(restaurantId)
      .collection('orders');

  @override
  Future<List<MenuItem>> getActiveMenu() async {
    try {
      final snapshot = await _menu.get();
      if (snapshot.docs.isEmpty) {
        return _seedDefaultMenu();
      }

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

    final now = DateTime.now();
    final requestId =
        '${customerSessionId}_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final callable = _functions.httpsCallable('submitOrder');
      final result = await callable.call(<String, Object?>{
        'requestId': requestId,
        'timestamp': now.toUtc().toIso8601String(),
        'payload': <String, Object?>{
          'restaurantId': restaurantId,
          'customerSessionId': customerSessionId,
          'branchId': branchId,
          'tableId': tableId,
          'tableSessionId': tableSessionId,
          'items': lines
              .map(
                (line) => <String, Object?>{
                  'menuItemId': line.item.id,
                  'quantity': line.quantity,
                },
              )
              .toList(growable: false),
        },
      });
      final envelope = _record(result.data);
      if (envelope['success'] != true) {
        final error = envelope['error'];
        final errorRecord = error is Map
            ? Map<String, dynamic>.from(error)
            : const <String, dynamic>{};
        throw StateError(
          errorRecord['message'] as String? ?? 'Unable to submit the order.',
        );
      }
      final data = _record(envelope['data']);
      final orderId = data['id'];
      if (orderId is! String || orderId.isEmpty) {
        throw StateError('The order response did not contain an order ID.');
      }
      return CustomerOrder(
        id: orderId,
        lines: List.unmodifiable(lines),
        status: OrderStatus.pending,
        createdAt: now,
      );
    } on StateError {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw StateError(
        error.message ?? 'Unable to submit the order. Please try again.',
      );
    } on FirebaseException catch (error) {
      throw StateError(
        _firebaseMessage(error, fallback: 'Unable to submit the order.'),
      );
    }
  }

  Map<String, dynamic> _record(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('The order response was invalid.');
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

  Future<List<MenuItem>> _seedDefaultMenu() async {
    final batch = _firestore.batch();
    for (final item in _defaultMenu) {
      final reference = _menu.doc(item.id);
      batch.set(reference, <String, Object?>{
        'id': item.id,
        'restaurantId': restaurantId,
        'branchId': branchId,
        'name': item.name,
        'description': item.description,
        'category': item.category,
        'price': item.price,
        'status': 'in_stock',
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    return List.unmodifiable(_defaultMenu);
  }

  MenuItem? _menuItemFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final documentRestaurantId = _optionalString(data['restaurantId']);
    if (documentRestaurantId != null && documentRestaurantId != restaurantId) {
      return null;
    }
    final documentBranchId = _optionalString(data['branchId']);
    if (documentBranchId != null && documentBranchId != branchId) return null;
    if (data['archived'] == true || data['isArchived'] == true) return null;

    final name = _optionalString(data['name']);
    final price = data['price'];
    if (name == null || price is! num || !price.isFinite || price < 0) {
      return null;
    }
    final isAvailable = data['isAvailable'];
    final available = isAvailable is bool
        ? isAvailable
        : data['availability'] == 'in_stock' || data['status'] == 'in_stock';
    if (!available) return null;

    return MenuItem(
      id: _optionalString(data['id']) ?? document.id,
      category:
          _optionalString(data['category']) ??
          _optionalString(data['categoryId']) ??
          'Menu',
      name: name,
      description: _optionalString(data['description']) ?? '',
      price: price.toInt(),
      available: true,
    );
  }

  String? _optionalString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
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
