import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startup_launch/app/theme/theme_cubit.dart';

void main() {
  group('ThemeCubit', () {
    test('initial state is system', () {
      expect(ThemeCubit().state, ThemeMode.system);
    });

    blocTest<ThemeCubit, ThemeMode>(
      'setLight emits light',
      build: ThemeCubit.new,
      act: (cubit) => cubit.setLight(),
      expect: () => [ThemeMode.light],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'setDark emits dark',
      build: ThemeCubit.new,
      act: (cubit) => cubit.setDark(),
      expect: () => [ThemeMode.dark],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'toggle cycles system -> light',
      build: ThemeCubit.new,
      act: (cubit) => cubit.toggle(),
      expect: () => [ThemeMode.light],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'toggle cycles light -> dark',
      build: ThemeCubit.new,
      seed: () => ThemeMode.light,
      act: (cubit) => cubit.toggle(),
      expect: () => [ThemeMode.dark],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'toggle cycles dark -> system',
      build: ThemeCubit.new,
      seed: () => ThemeMode.dark,
      act: (cubit) => cubit.toggle(),
      expect: () => [ThemeMode.system],
    );
  });
}
