import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:startup_launch/app/localization/locale_cubit.dart';
import 'package:startup_launch/app/routes/router.dart';
import 'package:startup_launch/app/theme/app_theme.dart';
import 'package:startup_launch/app/theme/theme_cubit.dart';
import 'package:startup_launch/core/config/app_config.dart';
import 'package:startup_launch/core/di/service_locator.dart';
import 'package:startup_launch/l10n/generated/app_localizations.dart';

class App extends StatelessWidget {
  const App({super.key, required this.showOnboardingFirst});

  final bool showOnboardingFirst;

  @override
  Widget build(BuildContext context) {
    final config = sl<AppConfig>();
    final GoRouter router = AppRouter.createRouter(
      showOnboardingFirst: showOnboardingFirst,
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<ThemeCubit>()),
        BlocProvider.value(value: sl<LocaleCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              final Widget child = MaterialApp.router(
                title: config.appName,
                debugShowCheckedModeBanner: false,
                routerConfig: router,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: mode,
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) {
                  if (!config.isProd) {
                    return Banner(
                      message: config.bannerLabel,
                      location: BannerLocation.topEnd,
                      color: config.bannerColor,
                      child: child!,
                    );
                  }
                  return child!;
                },
              );

              return child;
            },
          );
        },
      ),
    );
  }
}
