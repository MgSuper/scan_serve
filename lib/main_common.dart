import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:scan_serve/app/app.dart';
import 'package:scan_serve/app/localization/locale_cubit.dart';
import 'package:scan_serve/core/config/app_config.dart';
import 'package:scan_serve/core/config/environment.dart';
import 'package:scan_serve/core/di/service_locator.dart';
import 'package:scan_serve/core/utils/app_bloc_observer.dart';
import 'package:scan_serve/firebase_options.dart';

Future<void> bootstrap(Environment env) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final config = AppConfig.from(env);

  await _initializeFirebase();
  await setupLocator(config);

  await sl<LocaleCubit>().init();

  Bloc.observer = AppBlocObserver();

  runApp(const App());
  FlutterNativeSplash.remove();
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
