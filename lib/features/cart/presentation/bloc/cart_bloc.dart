import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scan_serve/features/cart/domain/use_cases/add_to_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/remove_from_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/submit_order_use_case.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_event.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({
    required AddToCart addToCart,
    required RemoveFromCart removeFromCart,
    required SubmitOrderUseCase submitOrder,
    required CartState initialState,
  }) : _addToCart = addToCart,
       _removeFromCart = removeFromCart,
       _submitOrder = submitOrder,
       super(initialState) {
    on<AddToCartEvent>(_onAddToCart);
    on<RemoveFromCartEvent>(_onRemoveFromCart);
    on<SubmitOrderEvent>(_onSubmitOrder);
  }

  final AddToCart _addToCart;
  final RemoveFromCart _removeFromCart;
  final SubmitOrderUseCase _submitOrder;

  Future<void> _onAddToCart(
    AddToCartEvent event,
    Emitter<CartState> emit,
  ) async {
    try {
      final cart = await _addToCart(
        cart: state.cart,
        menuItem: event.menuItem,
        quantity: event.quantity,
      );
      emit(CartLoaded(cart));
    } catch (error) {
      emit(CartError(state.cart, message: _message(error)));
    }
  }

  Future<void> _onRemoveFromCart(
    RemoveFromCartEvent event,
    Emitter<CartState> emit,
  ) async {
    try {
      final cart = await _removeFromCart(
        cart: state.cart,
        menuItemId: event.menuItemId,
        quantity: event.quantity,
      );
      emit(CartLoaded(cart));
    } catch (error) {
      emit(CartError(state.cart, message: _message(error)));
    }
  }

  Future<void> _onSubmitOrder(
    SubmitOrderEvent event,
    Emitter<CartState> emit,
  ) async {
    final currentCart = state.cart;
    emit(CartSubmitting(currentCart));
    try {
      final orderId = await _submitOrder(currentCart);
      // The backend clears the persisted cart after order creation. Clear the
      // in-memory cart as well so a later order cannot reuse stale menu IDs.
      emit(
        CartSubmitted(currentCart.copyWith(items: const []), orderId: orderId),
      );
    } catch (error) {
      emit(CartError(currentCart, message: _message(error)));
    }
  }

  String _message(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
