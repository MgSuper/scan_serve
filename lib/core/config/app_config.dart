import 'package:flutter/material.dart';

import 'environment.dart';

class AppConfig {
  final Environment env;
  final String baseUrl;
  final String appName;
  final Color bannerColor;

  const AppConfig({
    required this.env,
    required this.baseUrl,
    required this.appName,
    required this.bannerColor,
  });

  bool get isProd => env == Environment.prod;

  String get bannerLabel => env.name.toUpperCase();

  static AppConfig from(Environment env) {
    switch (env) {
      case Environment.dev:
        return const AppConfig(
          env: Environment.dev,
          baseUrl: 'https://dev.api.com',
          appName: 'Startup Launch Dev',
          bannerColor: Colors.green,
        );

      case Environment.staging:
        return const AppConfig(
          env: Environment.staging,
          baseUrl: 'https://staging.api.com',
          appName: 'Startup Launch Staging',
          bannerColor: Colors.orange,
        );

      case Environment.prod:
        return const AppConfig(
          env: Environment.prod,
          baseUrl: 'https://api.com',
          appName: 'Startup Launch',
          bannerColor: Colors.red,
        );
    }
  }
}
