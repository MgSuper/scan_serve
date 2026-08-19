import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:scan_serve/core/config/scan_serve_firestore_contract.dart';

import '../domain/customer_repository.dart';
import '../domain/models.dart';

class FirestoreCustomerRepository implements CustomerRepository {
  FirestoreCustomerRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    String? restaurantId,
    required this.tableId,
    String? branchId,
    String? tableSessionId,
    String? customerSessionId,
  }) : _firestore = firestore,
       _functions = functions,
       restaurantId = _normalizeIdentifier(
         restaurantId,
         ScanServeFirestoreContract.restaurantId,
       ),
       branchId = _normalizeIdentifier(
         branchId,
         ScanServeFirestoreContract.branchId,
       ),
       tableSessionId = _normalizeIdentifier(
         tableSessionId,
         ScanServeFirestoreContract.tableSessionId,
       ),
       customerSessionId = _normalizeIdentifier(
         customerSessionId,
         ScanServeFirestoreContract.customerSessionId,
       );

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
      final canonicalLines = await _canonicalizeMenuItemIds(lines);
      debugPrint(
        '[CustomerRepository] submitOrder cartPath=carts/$cartId '
        'restaurantId=$restaurantId branchId=$branchId '
        'customerSessionId=$customerSessionId '
        'menuItemIds=${canonicalLines.map((line) => line.item.id).toList()}',
      );
      await _ensureCustomerSession();
      await _persistCart(canonicalLines);
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
        lines: List.unmodifiable(canonicalLines),
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
    debugPrint(
      '[CustomerRepository] persistCart path=carts/$cartId '
      'menuItemIds=${lines.map((line) => line.item.id).toList()}',
    );
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

  Future<List<CartLine>> _canonicalizeMenuItemIds(List<CartLine> lines) async {
    final menuPath = 'restaurants/$restaurantId/menu';
    final snapshot = await _menu.get();
    final documentsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final document in snapshot.docs) document.id: document,
    };
    final documentsByLegacyId =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final document in snapshot.docs) {
      final legacyId = document.data()['id'];
      if (legacyId is String && legacyId.trim().isNotEmpty) {
        documentsByLegacyId[legacyId.trim()] = document;
      }
    }
    debugPrint(
      '[CustomerRepository] menuDocuments path=$menuPath '
      'documentIds=${snapshot.docs.map((document) => document.id).toList()}',
    );

    return lines
        .map((line) {
          final document =
              documentsById[line.item.id] ?? documentsByLegacyId[line.item.id];
          if (document == null || document.id == line.item.id) return line;
          final data = document.data();
          final canonicalItem = MenuItem(
            id: document.id,
            category: _optionalString(data['category']) ?? line.item.category,
            name: _optionalString(data['name']) ?? line.item.name,
            description:
                _optionalString(data['description']) ?? line.item.description,
            price: data['price'] is num && (data['price'] as num) >= 0
                ? (data['price'] as num).toInt()
                : line.item.price,
            available: data['isAvailable'] is bool
                ? data['isAvailable'] as bool
                : data['availability'] == 'in_stock' ||
                      data['status'] == 'in_stock',
          );
          debugPrint(
            '[CustomerRepository] canonicalized menuItemId=${line.item.id} '
            'to documentId=${document.id}',
          );
          return CartLine(item: canonicalItem, quantity: line.quantity);
        })
        .toList(growable: false);
  }

  String get cartId =>
      ScanServeFirestoreContract.canonicalCartId(customerSessionId);

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
      // The Firestore document ID is the canonical identifier sent to submitOrder.
      // The legacy `id` field may be stale or differ from the document path.
      id: document.id,
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
