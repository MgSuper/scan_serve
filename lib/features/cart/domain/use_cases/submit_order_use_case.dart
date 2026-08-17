import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/domain/repositories/cart_repository.dart';

class SubmitOrderUseCase {
  const SubmitOrderUseCase(this._repository);

  final CartRepository _repository;

  Future<String> call(Cart cart) {
    if (cart.items.isEmpty) {
      throw StateError('Add at least one item before submitting the order.');
    }
    return _repository.submitOrder(cart);
  }
}
