import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/domain/repositories/cart_repository.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';

class AddToCart {
  const AddToCart(this._repository);

  final CartRepository _repository;

  Future<Cart> call({
    required Cart cart,
    required MenuItem menuItem,
    int quantity = 1,
  }) async {
    if (!menuItem.isAvailable) {
      throw StateError('This menu item is currently unavailable.');
    }
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Quantity must be positive.',
      );
    }

    final items = [...cart.items];
    final existingIndex = items.indexWhere(
      (item) => item.menuItemId == menuItem.id,
    );
    if (existingIndex == -1) {
      items.add(
        CartItem(
          menuItemId: menuItem.id,
          name: menuItem.name,
          unitPrice: menuItem.price,
          quantity: quantity,
        ),
      );
    } else {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(
        name: menuItem.name,
        unitPrice: menuItem.price,
        quantity: existing.quantity + quantity,
      );
    }

    return _repository.saveCart(cart.copyWith(items: items));
  }
}
