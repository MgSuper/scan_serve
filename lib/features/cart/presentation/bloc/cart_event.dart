import 'package:equatable/equatable.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

final class AddToCartEvent extends CartEvent {
  const AddToCartEvent({required this.menuItem, this.quantity = 1});

  final MenuItem menuItem;
  final int quantity;

  @override
  List<Object?> get props => <Object?>[menuItem.id, quantity];
}

final class RemoveFromCartEvent extends CartEvent {
  const RemoveFromCartEvent({required this.menuItemId, this.quantity = 1});

  final String menuItemId;
  final int quantity;

  @override
  List<Object?> get props => <Object?>[menuItemId, quantity];
}

final class SubmitOrderEvent extends CartEvent {
  const SubmitOrderEvent();
}
