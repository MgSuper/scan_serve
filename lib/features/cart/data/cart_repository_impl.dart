import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:scan_serve/core/config/scan_serve_firestore_contract.dart';
import 'package:scan_serve/core/error/repository_exception.dart';
import 'package:scan_serve/features/cart/data/cart_mappers.dart';
import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/domain/repositories/cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  const CartRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Cart> saveCart(Cart cart) async {
    final canonicalCart = _withCanonicalCartId(cart);
    debugPrint(
      '[CartRepository] saveCart cartPath=carts/${canonicalCart.id} '
      'menuItemIds=${canonicalCart.items.map((item) => item.menuItemId).toList()}',
    );
    try {
      final dto = canonicalCart.toDto();
      await _firestore.collection('carts').doc(canonicalCart.id).set(
        <String, Object?>{
          'id': dto.id,
          'restaurantId': dto.restaurantId,
          'branchId': dto.branchId,
          'tableId': dto.tableId,
          'tableSessionId': dto.tableSessionId,
          'customerSessionId': dto.customerSessionId,
          'items': dto.items
              .map(
                (item) => <String, Object?>{
                  'menuItemId': item.menuItemId,
                  'name': item.name,
                  'unitPrice': item.unitPrice,
                  'quantity': item.quantity,
                  'note': item.note,
                  'modifiers': item.modifiers,
                },
              )
              .toList(growable: false),
          'subtotal': canonicalCart.subtotal,
          'totalQuantity': canonicalCart.totalQuantity,
          ...dto.metadata.toFirestore(),
        },
        SetOptions(merge: true),
      );
      return canonicalCart;
    } on FirebaseException catch (error) {
      throw RepositoryException(_firestoreMessage(error));
    } catch (error) {
      if (error is RepositoryException) rethrow;
      throw RepositoryException('Unable to update the cart.');
    }
  }

  @override
  Future<String> submitOrder(Cart cart) async {
    final requestId = _requestId(cart.id);
    try {
      final canonicalCart = await _canonicalizeMenuItemIds(
        _withCanonicalCartId(cart),
      );
      debugPrint(
        '[CartRepository] submitOrder cartPath=carts/${canonicalCart.id} '
        'restaurantId=${canonicalCart.restaurantId} branchId=${canonicalCart.branchId} '
        'customerSessionId=${canonicalCart.customerSessionId} '
        'menuItemIds=${canonicalCart.items.map((item) => item.menuItemId).toList()}',
      );
      // Re-persist the in-memory cart immediately before submission. This keeps
      // retries after a Firestore-side cart reset aligned with the UI state.
      await saveCart(canonicalCart);
      final callable = _functions.httpsCallable('submitOrder');
      final result = await callable.call(<String, Object?>{
        'requestId': requestId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'payload': <String, Object?>{
          'restaurantId': canonicalCart.restaurantId,
          'customerSessionId': canonicalCart.customerSessionId,
          'cartId': canonicalCart.id,
        },
      });
      debugPrint(
        '[CartRepository] submitOrder callable response=${result.data}',
      );
      final envelope = _record(result.data, 'The order response was invalid.');
      if (envelope['success'] != true) {
        final error = envelope['error'];
        final errorRecord = error is Map
            ? Map<String, dynamic>.from(error)
            : const <String, dynamic>{};
        throw RepositoryException(
          errorRecord['message'] as String? ?? 'Unable to submit the order.',
        );
      }
      final data = _record(envelope['data'], 'The order response was invalid.');
      final orderId = data['id'];
      if (orderId is! String || orderId.isEmpty) {
        throw RepositoryException(
          'The order response did not contain an order ID.',
        );
      }
      return orderId;
    } on RepositoryException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw RepositoryException(_functionsMessage(error));
    } on FirebaseException catch (error) {
      throw RepositoryException(_functionsMessage(error));
    } catch (error) {
      throw RepositoryException(
        'Unable to submit the order. Please try again.',
      );
    }
  }

  Cart _withCanonicalCartId(Cart cart) {
    final canonicalId = ScanServeFirestoreContract.canonicalCartId(
      cart.customerSessionId,
    );
    if (cart.id == canonicalId) return cart;
    return Cart(
      id: canonicalId,
      restaurantId: cart.restaurantId,
      branchId: cart.branchId,
      tableId: cart.tableId,
      tableSessionId: cart.tableSessionId,
      customerSessionId: cart.customerSessionId,
      items: cart.items,
      metadata: cart.metadata,
    );
  }

  Future<Cart> _canonicalizeMenuItemIds(Cart cart) async {
    final menuPath = 'restaurants/${cart.restaurantId}/menu';
    final snapshot = await _firestore
        .collection('restaurants')
        .doc(cart.restaurantId)
        .collection('menu')
        .get();
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
      '[CartRepository] menuDocuments path=$menuPath '
      'documentIds=${snapshot.docs.map((document) => document.id).toList()}',
    );

    var changed = false;
    final items = cart.items
        .map((item) {
          final document =
              documentsById[item.menuItemId] ??
              documentsByLegacyId[item.menuItemId];
          if (document == null || document.id == item.menuItemId) return item;
          changed = true;
          final data = document.data();
          final name = data['name'];
          final price = data['price'];
          debugPrint(
            '[CartRepository] canonicalized menuItemId=${item.menuItemId} '
            'to documentId=${document.id}',
          );
          return CartItem(
            menuItemId: document.id,
            name: name is String && name.trim().isNotEmpty ? name : item.name,
            unitPrice: price is num && price.isFinite && price >= 0
                ? price.toInt()
                : item.unitPrice,
            quantity: item.quantity,
            note: item.note,
            modifiers: item.modifiers,
          );
        })
        .toList(growable: false);
    return changed ? cart.copyWith(items: items) : cart;
  }

  Map<String, dynamic> _record(Object? value, String message) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw RepositoryException(message);
  }

  String _requestId(String cartId) =>
      '${cartId}_${DateTime.now().microsecondsSinceEpoch}';

  String _firestoreMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to update this cart.';
      case 'unavailable':
        return 'The cart service is temporarily unavailable. Please try again.';
      default:
        return 'Unable to update the cart.';
    }
  }

  String _functionsMessage(FirebaseException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Your dining session has expired. Please scan the table QR code again.';
      case 'deadline-exceeded':
      case 'unavailable':
        return 'The order service is temporarily unavailable. Please try again.';
      default:
        return 'Unable to submit the order. Please try again.';
    }
  }
}
