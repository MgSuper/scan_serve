import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
    try {
      final dto = cart.toDto();
      await _firestore.collection('carts').doc(cart.id).set(<String, Object?>{
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
        'subtotal': cart.subtotal,
        'totalQuantity': cart.totalQuantity,
        ...dto.metadata.toFirestore(),
      }, SetOptions(merge: true));
      return cart;
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
      final callable = _functions.httpsCallable('submitOrder');
      final result = await callable.call(<String, Object?>{
        'requestId': requestId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'payload': <String, Object?>{
          'restaurantId': cart.restaurantId,
          'customerSessionId': cart.customerSessionId,
          'cartId': cart.id,
        },
      });
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
