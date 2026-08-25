import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:scan_serve/app/routes/app_routes.dart';
import 'package:scan_serve/core/config/scan_serve_firestore_contract.dart';
import 'package:scan_serve/core/di/service_locator.dart';
import 'package:scan_serve/features/cart/domain/cart_entities.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:scan_serve/features/cart/presentation/bloc/cart_state.dart';
import 'package:scan_serve/features/cart/presentation/pages/cart_page.dart';
import 'package:scan_serve/features/customer/data/firestore_customer_repository.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';
import 'package:scan_serve/features/home/presentation/landing_screen.dart';
import 'package:scan_serve/features/menu/presentation/bloc/menu_bloc.dart';
import 'package:scan_serve/features/menu/presentation/pages/menu_page.dart';
import 'package:scan_serve/features/order_tracking/presentation/pages/order_tracking_page.dart';
import 'package:scan_serve/features/session/domain/session_context.dart';
import 'package:scan_serve/features/session/presentation/bloc/session_bloc.dart';
import 'package:scan_serve/features/session/presentation/bloc/session_event.dart';
import 'package:scan_serve/features/settings/presentation/screens/settings_screen.dart';

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: AppRoutes.home,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) {
            final session = _sessionContext(state);
            return MaterialPage(
              child: LandingScreen(
                restaurantName: _displayQuery(
                  state,
                  'restaurantName',
                  'ScanServe',
                ),
                branchName: _displayQuery(
                  state,
                  'branchName',
                  session.branchId,
                ),
                openingHours: _displayQuery(
                  state,
                  'openingHours',
                  '11:00 – 22:00',
                ),
                tableId: session.tableId,
                menuLocation: _menuLocation(session, state),
                repository: _customerRepository(session),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) =>
              const MaterialPage(child: SettingsPage()),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final session = _sessionContext(state);
            return MultiBlocProvider(
              providers: [
                BlocProvider<SessionBloc>(
                  create: (_) => SessionBloc()..add(SessionStarted(session)),
                ),
                BlocProvider<MenuBloc>(create: (_) => sl<MenuBloc>()),
                BlocProvider<CartBloc>(
                  create: (_) => sl<CartBloc>(
                    param1: CartInitial(_cartFromState(session, state)),
                  ),
                ),
              ],
              child: child,
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.menu,
              pageBuilder: (context, state) {
                final session = _sessionContext(state);
                return MaterialPage(
                  child: MenuPage(
                    restaurantId: session.restaurantId,
                    branchId: session.branchId,
                    tableId: session.tableId,
                    tableSessionId: session.tableSessionId,
                    customerSessionId: session.customerSessionId,
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutes.cart,
              pageBuilder: (context, state) =>
                  const MaterialPage(child: CartPage()),
            ),
            GoRoute(
              path: AppRoutes.orderTracking,
              pageBuilder: (context, state) => MaterialPage(
                child: OrderTrackingPage(
                  orderId: state.uri.queryParameters['orderId']?.trim() ?? '',
                ),
              ),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => _ErrorScreen(error: state.error),
    );
  }

  static SessionContext _sessionContext(GoRouterState state) =>
      SessionContext.fromQueryParameters(state.uri.queryParameters);

  static String _displayQuery(
    GoRouterState state,
    String key,
    String fallback,
  ) {
    final value = state.uri.queryParameters[key]?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  static CustomerRepository _customerRepository(SessionContext session) {
    if (!sl.isRegistered<FirebaseFirestore>() ||
        !sl.isRegistered<FirebaseFunctions>()) {
      return sl<CustomerRepository>();
    }
    return FirestoreCustomerRepository(
      firestore: sl<FirebaseFirestore>(),
      functions: sl<FirebaseFunctions>(),
      restaurantId: session.restaurantId,
      branchId: session.branchId,
      tableId: session.tableId,
      tableSessionId: session.tableSessionId,
      customerSessionId: session.customerSessionId,
      tableToken: session.tableToken,
    );
  }

  static String _menuLocation(SessionContext session, GoRouterState state) {
    final queryParameters = session.toQueryParameters();
    final cartId = state.uri.queryParameters['cartId']?.trim();
    if (cartId != null && cartId.isNotEmpty) queryParameters['cartId'] = cartId;
    return Uri(
      path: AppRoutes.menu,
      queryParameters: queryParameters,
    ).toString();
  }

  static Cart _cartFromState(SessionContext session, GoRouterState state) {
    final requestedCartId = state.uri.queryParameters['cartId']?.trim();
    return Cart.empty(
      id: requestedCartId == null || requestedCartId.isEmpty
          ? ScanServeFirestoreContract.canonicalCartId(
              session.customerSessionId,
            )
          : requestedCartId,
      restaurantId: session.restaurantId,
      branchId: session.branchId,
      tableId: session.tableId,
      tableSessionId: session.tableSessionId,
      customerSessionId: session.customerSessionId,
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
