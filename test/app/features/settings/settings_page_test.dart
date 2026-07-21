import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startup_launch/app/localization/locale_cubit.dart';
import 'package:startup_launch/app/theme/theme_cubit.dart';
import 'package:startup_launch/features/settings/presentation/screens/settings_screen.dart';
import 'package:startup_launch/l10n/generated/app_localizations.dart';

void main() {
  Widget buildTestable() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: MaterialApp(
        home: const SettingsPage(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    );
  }

  testWidgets('renders settings page', (tester) async {
    await tester.pumpWidget(buildTestable());

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tap dark mode works', (tester) async {
    await tester.pumpWidget(buildTestable());

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('tap vietnamese language works', (tester) async {
    await tester.pumpWidget(buildTestable());

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pump();

    expect(find.text('Tiếng Việt'), findsOneWidget);
  });
}
