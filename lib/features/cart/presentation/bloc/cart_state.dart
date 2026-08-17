import 'package:equatable/equatable.dart';
import 'package:scan_serve/features/cart/domain/cart_entities.dart';

sealed class CartState extends Equatable {
  const CartState(this.cart);

  final Cart cart;

  @override
  List<Object?> get props => <Object?>[
    cart.id,
    cart.items,
    cart.subtotal,
    cart.totalQuantity,
  ];
}

final class CartInitial extends CartState {
  const CartInitial(super.cart);
}

final class CartLoaded extends CartState {
  const CartLoaded(super.cart);
}

final class CartSubmitting extends CartState {
  const CartSubmitting(super.cart);
}

final class CartSubmitted extends CartState {
  const CartSubmitted(super.cart, {required this.orderId});

  final String orderId;

  @override
  List<Object?> get props => <Object?>[...super.props, orderId];
}

final class CartError extends CartState {
  const CartError(super.cart, {required this.message});

  final String message;

  @override
  List<Object?> get props => <Object?>[...super.props, message];
}
