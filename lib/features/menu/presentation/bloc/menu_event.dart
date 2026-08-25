import 'package:equatable/equatable.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';

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

final class MenuSearchChanged extends MenuEvent {
  const MenuSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

final class MenuCategoryChanged extends MenuEvent {
  const MenuCategoryChanged(this.categoryId);

  final String? categoryId;

  @override
  List<Object?> get props => <Object?>[categoryId];
}

final class MenuStreamUpdated extends MenuEvent {
  const MenuStreamUpdated(this.catalog);

  final MenuCatalog catalog;

  @override
  List<Object?> get props => <Object?>[catalog];
}

final class MenuStreamFailed extends MenuEvent {
  const MenuStreamFailed(this.error);

  final Object error;

  @override
  List<Object?> get props => <Object?>[error.toString()];
}
