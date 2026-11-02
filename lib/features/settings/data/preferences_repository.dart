import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_check/core/constants/app_constants.dart';

class PreferencesRepository {
  final SharedPreferences _prefs;

  PreferencesRepository(this._prefs);

  ThemeMode getThemeMode() {
    final modeStr = _prefs.getString(AppConstants.prefThemeMode);
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
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
    await _prefs.setString(AppConstants.prefThemeMode, modeStr);
  }

  // Floating widget position & size
  Offset? getWidgetPosition() {
    final x =
        _prefs.getDouble(AppConstants.prefWidgetPosX) ??
        _prefs.getDouble(AppConstants.legacyWidgetPosX);
    final y =
        _prefs.getDouble(AppConstants.prefWidgetPosY) ??
        _prefs.getDouble(AppConstants.legacyWidgetPosY);
    if (x != null && y != null) {
      return Offset(x, y);
    }
    return null;
  }

  Future<void> saveWidgetPosition(Offset position) async {
    await _prefs.setDouble(AppConstants.prefWidgetPosX, position.dx);
    await _prefs.setDouble(AppConstants.prefWidgetPosY, position.dy);
    await _prefs.remove(AppConstants.legacyWidgetPosX);
    await _prefs.remove(AppConstants.legacyWidgetPosY);
  }

  Size? getWidgetSize() {
    final w =
        _prefs.getDouble(AppConstants.prefWidgetWidth) ??
        _prefs.getDouble(AppConstants.legacyWidgetWidth);
    final h =
        _prefs.getDouble(AppConstants.prefWidgetHeight) ??
        _prefs.getDouble(AppConstants.legacyWidgetHeight);
    if (w != null && h != null) {
      return Size(w, h);
    }
    return null;
  }

  Future<void> saveWidgetSize(Size size) async {
    await _prefs.setDouble(AppConstants.prefWidgetWidth, size.width);
    await _prefs.setDouble(AppConstants.prefWidgetHeight, size.height);
    await _prefs.remove(AppConstants.legacyWidgetWidth);
    await _prefs.remove(AppConstants.legacyWidgetHeight);
  }

  bool get isWidgetAutoStartEnabled =>
      _prefs.getBool(AppConstants.prefWidgetAutoStart) ?? false;

  Future<void> setWidgetAutoStartEnabled(bool enabled) async {
    await _prefs.setBool(AppConstants.prefWidgetAutoStart, enabled);
  }

  // System notifications
  bool get notificationsEnabled =>
      _prefs.getBool(AppConstants.prefNotificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(AppConstants.prefNotificationsEnabled, enabled);
  }

  bool get notifyDueDates =>
      _prefs.getBool(AppConstants.prefNotifyDueDates) ?? true;

  Future<void> setNotifyDueDates(bool enabled) async {
    await _prefs.setBool(AppConstants.prefNotifyDueDates, enabled);
  }

  bool get notifyPriority =>
      _prefs.getBool(AppConstants.prefNotifyPriority) ?? true;

  Future<void> setNotifyPriority(bool enabled) async {
    await _prefs.setBool(AppConstants.prefNotifyPriority, enabled);
  }
}
