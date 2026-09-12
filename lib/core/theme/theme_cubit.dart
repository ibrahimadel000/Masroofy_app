import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final SharedPreferences _prefs;
  static const String keyThemeMode = 'themeMode';

  ThemeCubit({required SharedPreferences prefs})
      : _prefs = prefs,
        super(_getInitialThemeMode(prefs));

  static ThemeMode _getInitialThemeMode(SharedPreferences prefs) {
    final modeStr = prefs.getString(keyThemeMode);
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String modeStr;
    switch (mode) {
      case ThemeMode.light:
        modeStr = 'light';
        break;
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
    }
    await _prefs.setString(keyThemeMode, modeStr);
    emit(mode);
  }

  bool get isDarkMode {
    if (state == ThemeMode.dark) return true;
    if (state == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }
}
