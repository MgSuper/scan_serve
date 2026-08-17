import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scan_serve/features/menu/domain/use_cases/get_active_menu.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_event.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_state.dart';

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc({required GetActiveMenu getActiveMenu})
    : _getActiveMenu = getActiveMenu,
      super(const MenuInitial()) {
    on<LoadMenu>(_onLoadMenu);
    on<RefreshMenu>(_onRefreshMenu);
  }

  final GetActiveMenu _getActiveMenu;

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
    emit(const MenuLoading());
    try {
      final catalog = await _getActiveMenu(
        restaurantId: restaurantId,
        branchId: branchId,
      );
      emit(MenuLoaded(catalog));
    } catch (error) {
      emit(MenuError(_message(error)));
    }
  }

  String _message(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
