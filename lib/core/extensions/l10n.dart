import 'package:flutter/material.dart';
import 'package:startup_launch/l10n/generated/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
