import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get_it/get_it.dart';
import 'package:scan_serve/app/localization/locale_cubit.dart';
import 'package:scan_serve/app/theme/theme_cubit.dart';
import 'package:scan_serve/core/config/app_config.dart';
import 'package:scan_serve/core/network/api_client.dart';
import 'package:scan_serve/core/network/dio_factory.dart';
import 'package:scan_serve/features/cart/data/cart_repository_impl.dart';
import 'package:scan_serve/features/cart/domain/repositories/cart_repository.dart';
import 'package:scan_serve/features/cart/domain/use_cases/add_to_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/remove_from_cart.dart';
import 'package:scan_serve/features/cart/domain/use_cases/submit_order_use_case.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';
import 'package:scan_serve/features/customer/data/firestore_customer_repository.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';
import 'package:scan_serve/features/menu/data/menu_repository_impl.dart';
import 'package:scan_serve/features/menu/domain/repositories/menu_repository.dart';
import 'package:scan_serve/features/menu/domain/use_cases/get_active_menu.dart';
import 'package:scan_serve/features/menu/domain/use_cases/watch_active_menu.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_bloc.dart';

final sl = GetIt.instance;

Future<void> setupLocator(AppConfig config) async {
  // 1. Config first
  sl.registerSingleton<AppConfig>(config);

  // 2. Network layer
  final dio = DioFactory.create();
  sl.registerSingleton(dio);
  sl.registerLazySingleton(() => ApiClient(sl()));

  // 3. UI State (Theme & Locale)
  // Use registerSingleton instead of Lazy if you plan to init them immediately
  sl.registerSingleton(ThemeCubit());
  sl.registerSingleton(LocaleCubit());

  if (!sl.isRegistered<FirebaseFirestore>()) {
    sl.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance,
    );
  }
  if (!sl.isRegistered<FirebaseFunctions>()) {
    sl.registerLazySingleton<FirebaseFunctions>(
      () => FirebaseFunctions.instance,
    );
  }

  if (!sl.isRegistered<MenuRepository>()) {
    sl.registerLazySingleton<MenuRepository>(
      () => MenuRepositoryImpl(firestore: sl<FirebaseFirestore>()),
    );
  }
  if (!sl.isRegistered<CartRepository>()) {
    sl.registerLazySingleton<CartRepository>(
      () => CartRepositoryImpl(
        firestore: sl<FirebaseFirestore>(),
        functions: sl<FirebaseFunctions>(),
      ),
    );
  }
  if (!sl.isRegistered<GetActiveMenu>()) {
    sl.registerLazySingleton<GetActiveMenu>(
      () => GetActiveMenu(sl<MenuRepository>()),
    );
  }
  if (!sl.isRegistered<WatchActiveMenu>()) {
    sl.registerLazySingleton<WatchActiveMenu>(
      () => WatchActiveMenu(sl<MenuRepository>()),
    );
  }
  if (!sl.isRegistered<AddToCart>()) {
    sl.registerLazySingleton<AddToCart>(() => AddToCart(sl<CartRepository>()));
  }
  if (!sl.isRegistered<RemoveFromCart>()) {
    sl.registerLazySingleton<RemoveFromCart>(
      () => RemoveFromCart(sl<CartRepository>()),
    );
  }
  if (!sl.isRegistered<SubmitOrderUseCase>()) {
    sl.registerLazySingleton<SubmitOrderUseCase>(
      () => SubmitOrderUseCase(sl<CartRepository>()),
    );
  }
  if (!sl.isRegistered<MenuBloc>()) {
    sl.registerFactory<MenuBloc>(
      () => MenuBloc(
        getActiveMenu: sl<GetActiveMenu>(),
        watchActiveMenu: sl<WatchActiveMenu>(),
      ),
    );
  }
  if (!sl.isRegistered<CartBloc>()) {
    sl.registerFactoryParam<CartBloc, CartState, void>(
      (initialState, _) => CartBloc(
        addToCart: sl<AddToCart>(),
        removeFromCart: sl<RemoveFromCart>(),
        submitOrder: sl<SubmitOrderUseCase>(),
        initialState: initialState,
      ),
    );
  }

  if (!sl.isRegistered<CustomerRepository>()) {
    sl.registerLazySingleton<CustomerRepository>(
      () => FirestoreCustomerRepository(
        firestore: sl<FirebaseFirestore>(),
        functions: sl<FirebaseFunctions>(),
        restaurantId: const String.fromEnvironment(
          'SCAN_SERVE_RESTAURANT_ID',
          defaultValue: 'scanserve-demo',
        ),
        branchId: const String.fromEnvironment(
          'SCAN_SERVE_BRANCH_ID',
          defaultValue: 'main-branch',
        ),
        tableId: const String.fromEnvironment(
          'SCAN_SERVE_TABLE_ID',
          defaultValue: 'table-12',
        ),
        tableSessionId: const String.fromEnvironment(
          'SCAN_SERVE_TABLE_SESSION_ID',
          defaultValue: 'active-table-session',
        ),
        customerSessionId: const String.fromEnvironment(
          'SCAN_SERVE_CUSTOMER_SESSION_ID',
          defaultValue: 'active-customer-session',
        ),
      ),
    );
  }
}
