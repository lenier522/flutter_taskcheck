import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Gestiona el archivo de autostart de Linux para que el widget flotante
/// vuelva a abrirse automáticamente al iniciar sesión después de apagar o
/// reiniciar el equipo.
///
/// En lugar de apuntar el `.desktop` directamente al ejecutable (cuya ruta
/// cambia entre `flutter run`, builds locales y el paquete `.deb`), se genera
/// un lanzador estable en el directorio de datos de la app y se le añade una
/// pequeña espera para que el escritorio ya esté listo al arrancar.
class WidgetAutostartService {
  static const String _desktopFileName = 'taskcheck-widget.desktop';
  static const String _launcherFileName = 'taskcheck-widget.sh';

  /// Rutas habituales del ejecutable cuando la app está instalada como `.deb`.
  static const List<String> _installedExecutables = [
    '/opt/taskcheck/task_check',
    '/opt/task_check/task_check',
    '/usr/bin/task_check',
    '/usr/local/bin/task_check',
  ];

  static File? _autostartFile() {
    if (!Platform.isLinux) return null;

    final configHome = Platform.environment['XDG_CONFIG_HOME']?.trim();
    final home = Platform.environment['HOME']?.trim();
    final baseDir = (configHome != null && configHome.isNotEmpty)
        ? configHome
        : (home != null && home.isNotEmpty ? p.join(home, '.config') : null);
    if (baseDir == null) return null;

    return File(p.join(baseDir, 'autostart', _desktopFileName));
  }

  /// Indica si el widget está registrado para abrirse al iniciar sesión.
  static Future<bool> isEnabled() async {
    final file = _autostartFile();
    if (file == null) return false;
    try {
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Crea o elimina el archivo `.desktop` de autostart.
  static Future<bool> setEnabled(bool enabled) async {
    final file = _autostartFile();
    if (file == null) return false;

    try {
      if (!enabled) {
        if (await file.exists()) await file.delete();
        return true;
      }

      final launcherPath = await _writeLauncher();
      final content =
          '[Desktop Entry]\n'
          'Type=Application\n'
          'Version=1.0\n'
          'Name=TaskCheck Widget\n'
          'Comment=Ventana flotante de tareas de TaskCheck\n'
          'Exec=${_quoteExecutable(launcherPath)}\n'
          'Path=${p.dirname(launcherPath)}\n'
          'Terminal=false\n'
          'StartupNotify=false\n'
          'Hidden=false\n'
          'X-GNOME-Autostart-enabled=true\n'
          // Deja que el escritorio termine de arrancar antes de abrir la
          // ventana: al encender el equipo, lanzarla demasiado pronto puede
          // hacer que la ventana no llegue a mostrarse.
          'X-GNOME-Autostart-Delay=8\n'
          'X-KDE-autostart-after=panel\n';

      await file.parent.create(recursive: true);
      // Escribir primero en un archivo temporal evita dejar un .desktop
      // incompleto si el equipo se apaga durante la escritura.
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(content, flush: true);
      await temporary.rename(file.path);
      await _markExecutable(file);
      return true;
    } catch (error) {
      debugPrint('No se pudo configurar el autostart del widget: $error');
      return false;
    }
  }

  /// Escribe un lanzador estable que busca el ejecutable disponible.
  ///
  /// Así el autostart sigue funcionando aunque la app se actualice, cambie de
  /// ruta o se instale desde un `.deb` distinto al build usado al activarlo.
  static Future<String> _writeLauncher() async {
    final supportDir = await getApplicationSupportDirectory();
    final launcher = File(p.join(supportDir.path, _launcherFileName));

    final candidates = <String>[];
    void addCandidate(String? path) {
      final value = path?.trim();
      if (value == null || value.isEmpty) return;
      if (!candidates.contains(value)) candidates.add(value);
    }

    addCandidate(Platform.resolvedExecutable);
    for (final path in _installedExecutables) {
      addCandidate(path);
    }

    final buffer = StringBuffer()
      ..writeln('#!/bin/sh')
      ..writeln('# Generado automáticamente por TaskCheck.')
      ..writeln('# Abre el widget flotante al iniciar sesión.')
      ..writeln(
        '# La espera deja que el escritorio y el gestor de ventanas arranquen.',
      )
      ..writeln('sleep 5');

    for (final candidate in candidates) {
      final quoted = _quoteForShell(candidate);
      buffer
        ..writeln('if [ -x $quoted ]; then')
        ..writeln('  exec $quoted --widget >/dev/null 2>&1')
        ..writeln('fi');
    }

    buffer
      ..writeln('# Ninguna ruta existe: no hacer nada.')
      ..writeln('exit 0');

    await launcher.parent.create(recursive: true);
    await launcher.writeAsString(buffer.toString(), flush: true);
    await _markExecutable(launcher);
    return launcher.path;
  }

  static Future<void> _markExecutable(File file) async {
    if (!Platform.isLinux) return;
    try {
      await Process.run('chmod', ['755', file.path]);
    } catch (error) {
      debugPrint('No se pudieron ajustar los permisos de ${file.path}: $error');
    }
  }

  static String _quoteForShell(String value) {
    final escaped = value.replaceAll("'", r"'\''");
    return "'$escaped'";
  }

  static String _quoteExecutable(String executable) {
    final escaped = executable
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll(r'$', r'\$')
        .replaceAll('`', r'\`');
    return '"$escaped"';
  }
}
