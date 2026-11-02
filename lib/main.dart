import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_check/app.dart';
import 'package:task_check/core/constants/app_constants.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/features/desktop_widget/presentation/desktop_widget_app.dart';
import 'package:task_check/features/desktop_widget/services/widget_autostart_service.dart';
import 'package:task_check/features/desktop_widget/services/widget_instance_lock.dart';
import 'package:task_check/features/desktop_widget/services/widget_launcher.dart';
import 'package:task_check/features/desktop_widget/services/widget_window_bounds.dart';
import 'package:task_check/features/settings/data/preferences_repository.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Date formatting for Spanish locale
  await initializeDateFormatting('es', null);

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final preferences = PreferencesRepository(prefs);

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  final isWidgetMode = args.contains('--widget');

  if (isWidgetMode) {
    // A single widget process is allowed. A duplicate instance exits quietly.
    final instanceLock = await WidgetInstanceLock.tryAcquire();
    if (instanceLock == null) {
      exit(0);
    }

    // Keep the login auto-start entry fresh before showing the window, so the
    // widget reappears after a reboot even if the window is not ready yet.
    // It is only recreated when the user has auto-start enabled, so turning it
    // off in Settings is respected.
    if (preferences.isWidgetAutoStartEnabled) {
      await WidgetAutostartService.setEnabled(true);
    }

    // Restore the exact bounds where the widget was left. If the monitor
    // layout changed, the position is moved to a visible area.
    final bounds = await WidgetWindowBounds.restore(preferences);

    final windowOptions = WindowOptions(
      size: bounds.size,
      minimumSize: const Size(260, 50),
      center: bounds.position == null,
      title: '${AppConstants.appName} Widget',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
      alwaysOnTop: true,
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setBackgroundColor(Colors.transparent);
      if (bounds.position != null) {
        await windowManager.setPosition(bounds.position!);
      }
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: DesktopWidgetApp(instanceLock: instanceLock),
      ),
    );
  } else {
    // Main App Mode
    const windowOptions = WindowOptions(
      size: Size(
        AppConstants.defaultWindowWidth,
        AppConstants.defaultWindowHeight,
      ),
      minimumSize: Size(
        AppConstants.minWindowWidth,
        AppConstants.minWindowHeight,
      ),
      center: true,
      title: AppConstants.appName,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const TaskCheckApp(),
      ),
    );

    // If the widget was active during the previous session, open it again.
    // The instance lock prevents duplicates when the desktop already restored
    // it through the autostart entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(WidgetLauncher.restoreIfEnabled(preferences));
    });
  }
}
