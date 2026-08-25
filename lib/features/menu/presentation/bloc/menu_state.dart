import 'package:equatable/equatable.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';

sealed class MenuState extends Equatable {
  const MenuState({this.searchQuery = '', this.selectedCategoryId});

  final String searchQuery;
  final String? selectedCategoryId;

  @override
  List<Object?> get props => <Object?>[searchQuery, selectedCategoryId];
}

final class MenuInitial extends MenuState {
  const MenuInitial({super.searchQuery, super.selectedCategoryId});
}

final class MenuLoading extends MenuState {
  const MenuLoading({super.searchQuery, super.selectedCategoryId});
}

final class MenuLoaded extends MenuState {
  const MenuLoaded(this.catalog, {super.searchQuery, super.selectedCategoryId});

  final MenuCatalog catalog;

  @override
  List<Object?> get props => <Object?>[
    ...super.props,
    catalog.menu.id,
    catalog.categories,
    catalog.items,
  ];
}

final class MenuError extends MenuState {
  const MenuError(this.message, {super.searchQuery, super.selectedCategoryId});

  final String message;

  @override
  List<Object?> get props => <Object?>[...super.props, message];
}
