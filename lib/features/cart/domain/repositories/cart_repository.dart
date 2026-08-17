import 'package:scan_serve/features/cart/domain/cart_entities.dart';

abstract interface class CartRepository {
  Future<Cart> saveCart(Cart cart);

  Future<String> submitOrder(Cart cart);
}
