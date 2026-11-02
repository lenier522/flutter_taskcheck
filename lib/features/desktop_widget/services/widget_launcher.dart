import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:task_check/features/desktop_widget/services/widget_autostart_service.dart';
import 'package:task_check/features/settings/data/preferences_repository.dart';

/// Abre el widget flotante como un proceso independiente.
class WidgetLauncher {
  static Future<bool> launch() async {
    try {
      await Process.start(Platform.resolvedExecutable, const [
        '--widget',
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (error) {
      debugPrint('No se pudo abrir el widget flotante: $error');
      return false;
    }
  }

  /// Restaura el widget si estaba activo cuando se cerró la sesión anterior.
  static Future<bool> restoreIfEnabled(
    PreferencesRepository preferences,
  ) async {
    if (!preferences.isWidgetAutoStartEnabled) return false;

    // Recrear el archivo por si cambió la ruta del ejecutable o el usuario lo
    // eliminó manualmente.
    await WidgetAutostartService.setEnabled(true);
    return launch();
  }
}
