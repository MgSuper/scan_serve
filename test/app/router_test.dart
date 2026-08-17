import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scan_serve/app/localization/locale_cubit.dart';
import 'package:scan_serve/app/routes/router.dart';
import 'package:scan_serve/app/theme/theme_cubit.dart';
import 'package:scan_serve/core/di/service_locator.dart';
import 'package:scan_serve/features/customer/data/demo_customer_repository.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';
import 'package:scan_serve/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() {
    if (!sl.isRegistered<CustomerRepository>()) {
      sl.registerLazySingleton<CustomerRepository>(DemoCustomerRepository.new);
    }
  });

  Widget buildTestable() {
    final router = AppRouter.createRouter();

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

    expect(find.text('ScanServe'), findsOneWidget);
  });

  testWidgets('go to settings works', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });
}
