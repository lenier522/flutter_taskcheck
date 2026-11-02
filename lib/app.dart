import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:task_check/core/constants/app_constants.dart';
import 'package:task_check/core/database/database_sync_service.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/core/router/app_router.dart';
import 'package:task_check/core/theme/app_theme.dart';

class TaskCheckApp extends ConsumerWidget {
  const TaskCheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep database in real-time sync with changes from the floating widget
    ref.watch(databaseSyncServiceProvider);

    // Desktop notifications for tasks about to expire or still pending.
    ref.watch(taskNotificationSchedulerProvider);

    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
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
      routerConfig: router,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
