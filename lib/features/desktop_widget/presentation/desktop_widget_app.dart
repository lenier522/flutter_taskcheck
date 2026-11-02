import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:task_check/core/constants/app_constants.dart';
import 'package:task_check/core/database/database_sync_service.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/core/theme/app_theme.dart';
import 'package:task_check/features/desktop_widget/presentation/desktop_widget_window.dart';
import 'package:task_check/features/desktop_widget/services/widget_instance_lock.dart';

class DesktopWidgetApp extends ConsumerWidget {
  const DesktopWidgetApp({super.key, required this.instanceLock});

  final WidgetInstanceLock instanceLock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep database in real-time sync with changes from the main app
    ref.watch(databaseSyncServiceProvider);

    // The widget also notifies while the main window is closed.
    ref.watch(taskNotificationSchedulerProvider);

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: '${AppConstants.appName} Widget',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DesktopWidgetWindow(instanceLock: instanceLock),
    );
  }
}
