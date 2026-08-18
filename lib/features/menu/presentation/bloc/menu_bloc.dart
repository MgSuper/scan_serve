import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scan_serve/features/menu/domain/menu_entities.dart';
import 'package:scan_serve/features/menu/domain/use_cases/get_active_menu.dart';
import 'package:scan_serve/features/menu/domain/use_cases/watch_active_menu.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_event.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_state.dart';

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc({
    required GetActiveMenu getActiveMenu,
    required WatchActiveMenu watchActiveMenu,
  }) : _getActiveMenu = getActiveMenu,
       _watchActiveMenu = watchActiveMenu,
       super(const MenuInitial()) {
    on<LoadMenu>(_onLoadMenu);
    on<RefreshMenu>(_onRefreshMenu);
    on<MenuStreamUpdated>(_onMenuStreamUpdated);
    on<MenuStreamFailed>(_onMenuStreamFailed);
  }

  final GetActiveMenu _getActiveMenu;
  final WatchActiveMenu _watchActiveMenu;
  StreamSubscription<MenuCatalog>? _menuSubscription;

  Future<void> _onLoadMenu(LoadMenu event, Emitter<MenuState> emit) {
    return _load(event.restaurantId, event.branchId, emit);
  }

  Future<void> _onRefreshMenu(RefreshMenu event, Emitter<MenuState> emit) {
    return _load(event.restaurantId, event.branchId, emit);
  }

  Future<void> _load(
    String restaurantId,
    String branchId,
    Emitter<MenuState> emit,
  ) async {
    await _menuSubscription?.cancel();
    _menuSubscription = null;
    emit(const MenuLoading());
    try {
      final catalog = await _getActiveMenu(
        restaurantId: restaurantId,
        branchId: branchId,
      );
      emit(MenuLoaded(catalog));
      _menuSubscription =
          _watchActiveMenu(
            restaurantId: restaurantId,
            branchId: branchId,
          ).listen(
            (catalog) => add(MenuStreamUpdated(catalog)),
            onError: (Object error, StackTrace _) =>
                add(MenuStreamFailed(error)),
          );
    } catch (error) {
      emit(MenuError(_message(error)));
    }
  }

  void _onMenuStreamUpdated(MenuStreamUpdated event, Emitter<MenuState> emit) {
    emit(MenuLoaded(event.catalog));
  }

  void _onMenuStreamFailed(MenuStreamFailed event, Emitter<MenuState> emit) {
    emit(MenuError(_message(event.error)));
  }

  String _message(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  @override
  Future<void> close() async {
    await _menuSubscription?.cancel();
    return super.close();
  }
}
