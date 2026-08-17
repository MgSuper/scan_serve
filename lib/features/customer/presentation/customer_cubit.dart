import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/customer_repository.dart';
import '../domain/models.dart';

class CustomerState {
  const CustomerState({
    this.loading = true,
    this.menu = const [],
    this.cart = const [],
    this.order,
    this.message,
  });

  final bool loading;
  final List<MenuItem> menu;
  final List<CartLine> cart;
  final CustomerOrder? order;
  final String? message;

  int get cartTotal => cart.fold(0, (sum, line) => sum + line.total);
  int get cartQuantity => cart.fold(0, (sum, line) => sum + line.quantity);

  CustomerState copyWith({
    bool? loading,
    List<MenuItem>? menu,
    List<CartLine>? cart,
    CustomerOrder? order,
    bool clearOrder = false,
    String? message,
    bool clearMessage = false,
  }) => CustomerState(
    loading: loading ?? this.loading,
    menu: menu ?? this.menu,
    cart: cart ?? this.cart,
    order: clearOrder ? null : order ?? this.order,
    message: clearMessage ? null : message ?? this.message,
  );
}

class CustomerCubit extends Cubit<CustomerState> {
  CustomerCubit(this._repository) : super(const CustomerState());
  final CustomerRepository _repository;
  StreamSubscription<CustomerOrder?>? _activeOrderSubscription;

  Future<void> load() async {
    try {
      final results = await Future.wait([
        _repository.getActiveMenu(),
        _repository.getActiveOrder().first,
      ]);
      emit(
        state.copyWith(
          loading: false,
          menu: List.unmodifiable(results[0] as List<MenuItem>),
          order: results[1] as CustomerOrder?,
          clearMessage: true,
        ),
      );
      _watchActiveOrder();
    } catch (_) {
      emit(
        state.copyWith(
          loading: false,
          message: 'Unable to load the menu. Please try again.',
        ),
      );
    }
  }

  void add(MenuItem item) {
    final cart = [...state.cart];
    final index = cart.indexWhere((line) => line.item.id == item.id);
    if (index == -1) {
      cart.add(CartLine(item: item, quantity: 1));
    } else {
      cart[index] = cart[index].copyWith(quantity: cart[index].quantity + 1);
    }
    emit(state.copyWith(cart: List.unmodifiable(cart), clearMessage: true));
  }

  void changeQuantity(MenuItem item, int quantity) {
    final cart = [...state.cart];
    final index = cart.indexWhere((line) => line.item.id == item.id);
    if (index < 0) return;
    if (quantity <= 0) {
      cart.removeAt(index);
    } else {
      cart[index] = cart[index].copyWith(quantity: quantity);
    }
    emit(state.copyWith(cart: List.unmodifiable(cart)));
  }

  Future<void> submitOrder() async {
    try {
      final order = await _repository.submitOrder(state.cart);
      emit(
        state.copyWith(
          cart: const [],
          order: order,
          message: 'Order ${order.id} sent to the kitchen.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          message: error.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }

  void _watchActiveOrder() {
    _activeOrderSubscription?.cancel();
    _activeOrderSubscription = _repository.getActiveOrder().listen((order) {
      if (isClosed || order == state.order) return;
      emit(state.copyWith(order: order, clearOrder: order == null));
    }, onError: (_) {});
  }

  @override
  Future<void> close() async {
    await _activeOrderSubscription?.cancel();
    return super.close();
  }

  Future<void> callWaiter() async {
    try {
      await _repository.requestWaiter();
      emit(state.copyWith(message: 'A waiter has been notified.'));
    } catch (_) {
      emit(
        state.copyWith(message: 'Unable to notify a waiter. Please try again.'),
      );
    }
  }
}
