import 'package:equatable/equatable.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';

sealed class MenuState extends Equatable {
  const MenuState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class MenuInitial extends MenuState {
  const MenuInitial();
}

final class MenuLoading extends MenuState {
  const MenuLoading();
}

final class MenuLoaded extends MenuState {
  const MenuLoaded(this.catalog);

  final MenuCatalog catalog;

  @override
  List<Object?> get props => <Object?>[
    catalog.menu.id,
    catalog.categories,
    catalog.items,
  ];
}

final class MenuError extends MenuState {
  const MenuError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
