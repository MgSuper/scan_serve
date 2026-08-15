import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scan_serve/app/localization/locale_cubit.dart';
import 'package:scan_serve/app/routes/router.dart';
import 'package:scan_serve/app/theme/theme_cubit.dart';
import 'package:scan_serve/core/di/service_locator.dart';
import 'package:scan_serve/features/onboarding/data/onboarding_storage.dart';
import 'package:scan_serve/l10n/generated/app_localizations.dart';

class FakeOnboardingStorage implements OnboardingStorage {
  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> setCompleted() async {}
}

void main() {
  setUpAll(() {
    if (!sl.isRegistered<OnboardingStorage>()) {
      sl.registerLazySingleton<OnboardingStorage>(FakeOnboardingStorage.new);
    }
  });

  Widget buildTestable() {
    final router = AppRouter.createRouter(showOnboardingFirst: false);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
  }

  testWidgets('home route loads', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('go to settings works', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });
}
