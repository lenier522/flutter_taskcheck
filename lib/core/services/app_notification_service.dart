import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:task_check/core/services/task_notifications.dart';

/// Envía notificaciones nativas del escritorio (Linux/Windows/macOS).
class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _available = true;
  Future<bool>? _initializing;

  /// Inicializa el plugin una sola vez. Devuelve `false` si el sistema no
  /// permite notificaciones (por ejemplo, sin servidor de notificaciones).
  Future<bool> ensureInitialized() {
    return _initializing ??= _initialize();
  }

  Future<bool> _initialize() async {
    if (_initialized) return _available;
    try {
      const settings = InitializationSettings(
        linux: LinuxInitializationSettings(
          defaultActionName: 'Abrir TaskCheck',
        ),
        macOS: DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'TaskCheck',
          appUserModelId: 'com.taskcheck.task_check',
          guid: 'a3b8c3e8-6c1a-4c2f-9a8e-2f4f2f1a9c11',
        ),
      );
      _initialized = await _plugin.initialize(settings: settings) ?? false;
      _available = _initialized;
    } catch (error) {
      debugPrint('No se pudo inicializar las notificaciones: $error');
      _available = false;
    }
    return _available;
  }

  /// Muestra un aviso de tarea. Devuelve `true` si el sistema lo aceptó.
  Future<bool> show(TaskNotification notification) async {
    if (!await ensureInitialized()) return false;

    final details = NotificationDetails(
      linux: LinuxNotificationDetails(
        urgency: notification.kind == TaskNotificationKind.overdue
            ? LinuxNotificationUrgency.critical
            : LinuxNotificationUrgency.normal,
        timeout: const LinuxNotificationTimeout(8000),
      ),
      macOS: const DarwinNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );

    try {
      await _plugin.show(
        id: notification.notificationId,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: notification.task.id,
      );
      return true;
    } catch (error) {
      debugPrint('No se pudo mostrar la notificación: $error');
      return false;
    }
  }

  /// Aviso de prueba para verificar que el escritorio los muestra.
  Future<bool> showTest() async {
    if (!await ensureInitialized()) return false;

    try {
      await _plugin.show(
        id: 1,
        title: 'TaskCheck',
        body: 'Las notificaciones del sistema están funcionando correctamente.',
        notificationDetails: const NotificationDetails(
          linux: LinuxNotificationDetails(
            urgency: LinuxNotificationUrgency.normal,
            timeout: LinuxNotificationTimeout(6000),
          ),
          macOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('No se pudo mostrar la notificación de prueba: $error');
      return false;
    }
  }

  /// Indica si la aplicación corre en una plataforma con notificaciones.
  bool get isSupportedPlatform =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
