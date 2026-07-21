import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(_getInitialLocale());

  static const _storageKey = 'language_code';

  static Locale _getInitialLocale() {
    final String deviceLanguage =
        PlatformDispatcher.instance.locale.languageCode;

    const supported = ['en', 'vi', 'ja', 'th'];

    if (supported.contains(deviceLanguage)) {
      return Locale(deviceLanguage);
    }

    return const Locale('en');
  }

  /// Call in main.dart after setupLocator()
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage = prefs.getString(_storageKey);

    if (savedLanguage != null && savedLanguage.isNotEmpty) {
      emit(Locale(savedLanguage));
    }
  }

  Future<void> change(String code) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_storageKey, code);

    emit(Locale(code));
  }

  Future<void> resetToDeviceLocale() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);

    emit(_getInitialLocale());
  }

  bool isSupported(String code) {
    const supported = ['en', 'vi', 'ja', 'th'];
    return supported.contains(code);
  }
}
