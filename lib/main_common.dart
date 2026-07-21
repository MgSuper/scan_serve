import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:startup_launch/app/app.dart';
import 'package:startup_launch/app/localization/locale_cubit.dart';
import 'package:startup_launch/core/config/app_config.dart';
import 'package:startup_launch/core/config/environment.dart';
import 'package:startup_launch/core/di/service_locator.dart';
import 'package:startup_launch/core/utils/app_bloc_observer.dart';
import 'package:startup_launch/features/onboarding/data/onboarding_storage.dart';

Future<void> bootstrap(Environment env) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final config = AppConfig.from(env);

  await setupLocator(config);

  await sl<LocaleCubit>().init();

  Bloc.observer = AppBlocObserver();

  final onboardingCompleted = await sl<OnboardingStorage>().isCompleted();

  runApp(App(showOnboardingFirst: !onboardingCompleted));
  FlutterNativeSplash.remove();
}
