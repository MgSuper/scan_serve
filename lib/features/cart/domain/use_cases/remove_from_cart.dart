import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/domain/repositories/cart_repository.dart';

class RemoveFromCart {
  const RemoveFromCart(this._repository);

  final CartRepository _repository;

  Future<Cart> call({
    required Cart cart,
    required String menuItemId,
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Quantity must be positive.',
      );
    }

    final index = cart.items.indexWhere(
      (item) => item.menuItemId == menuItemId,
    );
    if (index == -1) return cart;

    final items = [...cart.items];
    final current = items[index];
    final remainingQuantity = current.quantity - quantity;
    if (remainingQuantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = current.copyWith(quantity: remainingQuantity);
    }

    return _repository.saveCart(cart.copyWith(items: items));
  }
}
