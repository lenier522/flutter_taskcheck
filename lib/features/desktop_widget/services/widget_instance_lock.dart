import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Evita que se abran varias ventanas flotantes del widget al mismo tiempo.
///
/// Usa un bloqueo de archivo no bloqueante. El sistema operativo libera el
/// bloqueo automáticamente si el proceso termina de forma abrupta.
class WidgetInstanceLock {
  WidgetInstanceLock._(this._handle);

  final RandomAccessFile? _handle;
  bool _released = false;

  /// Devuelve `null` cuando ya existe otra instancia del widget en ejecución.
  static Future<WidgetInstanceLock?> tryAcquire() async {
    RandomAccessFile? handle;
    try {
      final supportDir = await getApplicationSupportDirectory();
      final lockFile = File(p.join(supportDir.path, 'widget.lock'));
      await lockFile.parent.create(recursive: true);

      handle = await lockFile.open(mode: FileMode.write);
      try {
        await handle.lock(FileLock.exclusive);
      } on FileSystemException {
        await handle.close();
        return null;
      }

      return WidgetInstanceLock._(handle);
    } catch (error) {
      // Si el bloqueo no se puede crear por un problema del sistema de
      // archivos, permitimos abrir el widget en lugar de bloquear al usuario.
      debugPrint('No se pudo crear el bloqueo del widget: $error');
      await handle?.close();
      return WidgetInstanceLock._(null);
    }
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    try {
      await _handle?.unlock();
    } catch (error) {
      debugPrint('No se pudo liberar el bloqueo del widget: $error');
    }
    try {
      await _handle?.close();
    } catch (error) {
      debugPrint('No se pudo cerrar el archivo de bloqueo del widget: $error');
    }
  }
}
