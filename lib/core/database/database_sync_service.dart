import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/providers.dart';

/// Provider for the bidirectional database synchronization service.
final databaseSyncServiceProvider = Provider<DatabaseSyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = DatabaseSyncService(db);
  service.start();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Service that coordinates real-time synchronization between the main app and
/// the floating desktop widget processes via SQLite + file signal notifications.
class DatabaseSyncService {
  final AppDatabase _db;
  StreamSubscription? _dirWatchSub;
  Timer? _fallbackTimer;
  File? _signalFile;
  bool _isDisposed = false;

  DatabaseSyncService(this._db);

  Future<void> start() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _signalFile = File(p.join(dir.path, 'sync_signal'));
      if (!await _signalFile!.exists()) {
        await _signalFile!.create(recursive: true);
        await _signalFile!.writeAsString('0');
      }

      // Watch parent directory for instant inotify signal changes
      _dirWatchSub = _signalFile!.parent.watch().listen((event) {
        if (_isDisposed) return;
        if (p.basename(event.path) == 'sync_signal') {
          _db.syncFromDisk();
        }
      });
    } catch (_) {
      // In case inotify is restricted, fallback timer handles it
    }

    // Fallback periodic timer: guarantees sync every 1 second
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isDisposed) {
        _db.syncFromDisk();
      }
    });
  }

  /// Triggers a sync signal so other processes (main app or desktop widget)
  /// update immediately in sub-second real time.
  Future<void> notifyChange() async {
    try {
      if (_signalFile != null) {
        await _signalFile!.writeAsString(
          '${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (_) {}
  }

  void dispose() {
    _isDisposed = true;
    _dirWatchSub?.cancel();
    _fallbackTimer?.cancel();
  }
}
