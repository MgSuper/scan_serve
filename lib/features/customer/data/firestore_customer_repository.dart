import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/customer_repository.dart';
import '../domain/models.dart';

class FirestoreCustomerRepository implements CustomerRepository {
  static const defaultRestaurantId = 'scanserve-demo';
  static const defaultBranchId = 'main-branch';

  FirestoreCustomerRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    String? restaurantId,
    required this.tableId,
    String? branchId,
    this.tableSessionId = 'active-table-session',
    this.customerSessionId = 'active-customer-session',
  }) : _firestore = firestore,
       _functions = functions,
       restaurantId = _normalizeIdentifier(restaurantId, defaultRestaurantId),
       branchId = _normalizeIdentifier(branchId, defaultBranchId);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String restaurantId;
  final String branchId;
  final String tableId;
  final String tableSessionId;
  final String customerSessionId;

  static String _normalizeIdentifier(String? value, String fallback) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }

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
      await _ensureCustomerSession();
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
  Stream<CustomerOrder?> getActiveOrder() async* {
    try {
      await for (final snapshot
          in _orders
              .where('tableId', isEqualTo: tableId)
              .where('customerSessionId', isEqualTo: customerSessionId)
              .where(
                'status',
                whereIn: const ['PENDING', 'ACCEPTED', 'PREPARING', 'READY'],
              )
              .snapshots()) {
        final orders = snapshot.docs
            .map(_orderFromDocument)
            .whereType<CustomerOrder>()
            .where((order) => _isActive(order.status))
            .toList(growable: false);
        if (orders.isEmpty) {
          yield null;
          continue;
        }
        orders.sort((left, right) => right.createdAt.compareTo(left.createdAt));
        yield orders.first;
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'unavailable') {
        yield null;
        return;
      }
      throw StateError(
        _firebaseMessage(error, fallback: 'Unable to sync the active order.'),
      );
    } catch (_) {
      yield null;
    }
  }

  @override
  Future<CustomerOrder> submitOrder(List<CartLine> lines) async {
    if (lines.isEmpty) throw StateError('Your cart is empty.');

    final now = DateTime.now();
    final requestId =
        '${customerSessionId}_${DateTime.now().microsecondsSinceEpoch}';
    final cartReferenceId = cartId;
    try {
      await _ensureCustomerSession();
      await _persistCart(lines);
      final callable = _functions.httpsCallable('submitOrder');
      final result = await callable.call(<String, Object?>{
        'requestId': requestId,
        'timestamp': now.toUtc().toIso8601String(),
        'payload': <String, Object?>{
          'restaurantId': restaurantId,
          'customerSessionId': customerSessionId,
          'cartId': cartReferenceId,
          'branchId': branchId,
          'tableId': tableId,
          'tableSessionId': tableSessionId,
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

  Future<void> _persistCart(List<CartLine> lines) async {
    final cartReference = _firestore.collection('carts').doc(cartId);
    final items = lines
        .map(
          (line) => <String, Object?>{
            'menuItemId': line.item.id,
            'name': line.item.name,
            'unitPrice': line.item.price,
            'quantity': line.quantity,
            'lineTotal': line.total,
            'note': null,
            'modifiers': const <String>[],
          },
        )
        .toList(growable: false);
    await cartReference.set(<String, Object?>{
      'id': cartId,
      'restaurantId': restaurantId,
      'branchId': branchId,
      'tableId': tableId,
      'tableSessionId': tableSessionId,
      'customerSessionId': customerSessionId,
      'items': items,
      'totalQuantity': lines.fold<int>(
        0,
        (total, line) => total + line.quantity,
      ),
      'subtotal': lines.fold<int>(0, (total, line) => total + line.total),
      'isArchived': false,
      'deletedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String get cartId =>
      'cart_${customerSessionId.trim().isEmpty ? tableSessionId : customerSessionId}';

  Future<void> _ensureCustomerSession() async {
    final sessionReference = _firestore
        .collection('customerSessions')
        .doc(customerSessionId);
    final now = DateTime.now().toUtc();
    await sessionReference.set(<String, Object?>{
      'id': customerSessionId,
      'customerSessionId': customerSessionId,
      'restaurantId': restaurantId,
      'branchId': branchId,
      'tableId': tableId,
      'tableSessionId': tableSessionId,
      'status': 'ACTIVE',
      'isActive': true,
      'isArchived': false,
      'deletedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    }, SetOptions(merge: true));
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
