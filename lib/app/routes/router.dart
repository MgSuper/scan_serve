import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_serve/app/routes/app_routes.dart';
import 'package:scan_serve/core/di/service_locator.dart';
import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';
import 'package:scan_serve/features/cart/presentation/pages/cart_page.dart';
import 'package:scan_serve/features/home/presentation/home_screen.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:scan_serve/features/menu/presentation/pages/menu_page.dart';
import 'package:scan_serve/features/onboarding/data/onboarding_storage.dart';
import 'package:scan_serve/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:scan_serve/features/onboarding/presentation/onboarding_screen.dart';
import 'package:scan_serve/features/order_tracking/presentation/pages/order_tracking_page.dart';
import 'package:scan_serve/features/settings/presentation/screens/settings_screen.dart';

class AppRouter {
  static GoRouter createRouter({required bool showOnboardingFirst}) {
    return GoRouter(
      initialLocation: showOnboardingFirst
          ? AppRoutes.onboarding
          : AppRoutes.home,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.onboarding,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(
              create: (_) => OnboardingCubit(storage: sl<OnboardingStorage>()),
              child: const OnboardingScreen(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) =>
              const MaterialPage(child: HomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) =>
              const MaterialPage(child: SettingsPage()),
        ),
        ShellRoute(
          builder: (context, state, child) => MultiBlocProvider(
            providers: [
              BlocProvider<MenuBloc>(create: (_) => sl<MenuBloc>()),
              BlocProvider<CartBloc>(
                create: (_) =>
                    sl<CartBloc>(param1: CartInitial(_cartFromState(state))),
              ),
            ],
            child: child,
          ),
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.menu,
              pageBuilder: (context, state) => MaterialPage(
                child: MenuPage(
                  restaurantId: _query(state, 'restaurantId'),
                  branchId: _query(state, 'branchId'),
                ),
              ),
            ),
            GoRoute(
              path: AppRoutes.cart,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: CartPage()),
            ),
            GoRoute(
              path: AppRoutes.orderTracking,
              pageBuilder: (context, state) => MaterialPage(
                child: OrderTrackingPage(orderId: _query(state, 'orderId')),
              ),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => _ErrorScreen(error: state.error),
    );
  }

  static String _query(GoRouterState state, String key) {
    return state.uri.queryParameters[key] ?? '';
  }

  static Cart _cartFromState(GoRouterState state) {
    final restaurantId = _query(state, 'restaurantId');
    final branchId = _query(state, 'branchId');
    final customerSessionId = _query(state, 'customerSessionId');
    return Cart.empty(
      id: _query(state, 'cartId').isEmpty
          ? 'cart-$customerSessionId'
          : _query(state, 'cartId'),
      restaurantId: restaurantId,
      branchId: branchId,
      tableId: _query(state, 'tableId'),
      tableSessionId: _query(state, 'tableSessionId'),
      customerSessionId: customerSessionId,
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation error')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          error?.toString() ?? 'Unknown routing error',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
