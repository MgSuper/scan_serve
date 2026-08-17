import 'package:equatable/equatable.dart';

sealed class MenuEvent extends Equatable {
  const MenuEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

final class LoadMenu extends MenuEvent {
  const LoadMenu({required this.restaurantId, required this.branchId});

  final String restaurantId;
  final String branchId;

  @override
  List<Object?> get props => <Object?>[restaurantId, branchId];
}

final class RefreshMenu extends MenuEvent {
  const RefreshMenu({required this.restaurantId, required this.branchId});

  final String restaurantId;
  final String branchId;

  @override
  List<Object?> get props => <Object?>[restaurantId, branchId];
}
