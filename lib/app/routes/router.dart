import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:startup_launch/app/routes/app_routes.dart';
import 'package:startup_launch/core/di/service_locator.dart';
import 'package:startup_launch/features/home/presentation/home_screen.dart';
import 'package:startup_launch/features/onboarding/data/onboarding_storage.dart';
import 'package:startup_launch/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:startup_launch/features/onboarding/presentation/onboarding_screen.dart';
import 'package:startup_launch/features/settings/presentation/screens/settings_screen.dart';

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
      ],
      errorBuilder: (context, state) => _ErrorScreen(error: state.error),
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
