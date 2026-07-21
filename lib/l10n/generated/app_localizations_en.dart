// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Startup Launcher';

  @override
  String get homeTitle => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get auto => 'Auto';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get onboardingTitle1 => 'Launch ideas faster';

  @override
  String get onboardingDesc1 =>
      'Start your next Flutter app with production-ready architecture, themes, routing, and localization already setup.';

  @override
  String get onboardingTitle2 => 'Built for serious startups';

  @override
  String get onboardingDesc2 =>
      'Use clean structure, scalable state management, networking, and CI/CD from day one.';

  @override
  String get onboardingTitle3 => 'Save weeks of setup';

  @override
  String get onboardingDesc3 =>
      'No more repeating flavors, rename configs, tests, icons, or boilerplate every new project.';

  @override
  String get onboardingTitle4 => 'Build. Launch. Grow.';

  @override
  String get onboardingDesc4 =>
      'Focus on solving real problems and shipping products faster with Startup Launch.';
}
