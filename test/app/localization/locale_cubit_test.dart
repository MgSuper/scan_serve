import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_launch/app/localization/locale_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial locale is supported', () {
      final cubit = LocaleCubit();

      expect(['en', 'vi', 'ja', 'th'].contains(cubit.state.languageCode), true);
    });

    blocTest<LocaleCubit, Locale>(
      'change to vietnamese',
      build: LocaleCubit.new,
      act: (cubit) async => await cubit.change('vi'),
      expect: () => [const Locale('vi')],
    );

    blocTest<LocaleCubit, Locale>(
      'change to japanese',
      build: LocaleCubit.new,
      act: (cubit) async => await cubit.change('ja'),
      expect: () => [const Locale('ja')],
    );

    blocTest<LocaleCubit, Locale>(
      'reset returns device/default locale',
      build: LocaleCubit.new,
      act: (cubit) async => await cubit.resetToDeviceLocale(),
      expect: () => [
        predicate<Locale>(
          (locale) => ['en', 'vi', 'ja', 'th'].contains(locale.languageCode),
        ),
      ],
    );
  });
}
