import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_check/core/constants/app_constants.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/services/app_notification_service.dart';
import 'package:task_check/core/services/task_notifications.dart';
import 'package:task_check/features/tasks/domain/task.dart';

/// Vigila las tareas y lanza notificaciones del sistema cuando una tarea está
/// a punto de vencer, ya venció o lleva demasiado tiempo siendo prioritaria.
class TaskNotificationScheduler {
  TaskNotificationScheduler(
    this._db,
    this._preferences, {
    AppNotificationService? notifications,
    this.tick = const Duration(minutes: 1),
  }) : _notifications = notifications ?? AppNotificationService.instance;

  final AppDatabase _db;
  final SharedPreferences _preferences;
  final AppNotificationService _notifications;
  final Duration tick;

  StreamSubscription<List<Task>>? _subscription;
  Timer? _timer;
  List<Task> _tasks = const [];
  File? _historyFile;
  DateTime? _lastRun;
  bool _evaluating = false;
  bool _started = false;
  bool _disposed = false;

  static const Duration _minInterval = Duration(seconds: 20);
  static const Duration _historyRetention = Duration(days: 7);

  /// Comienza a escuchar cambios y a evaluar recordatorios periódicamente.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    try {
      final dir = await getApplicationSupportDirectory();
      _historyFile = File(p.join(dir.path, 'notification_history.json'));
    } catch (error) {
      debugPrint('No se pudo preparar el historial de notificaciones: $error');
    }

    _subscription = _db.watchTasksWithDetails(isArchived: false).listen((
      tasks,
    ) {
      _tasks = tasks;
      unawaited(_evaluate());
    });

    _timer = Timer.periodic(tick, (_) => unawaited(_evaluate()));
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _timer?.cancel();
  }

  Future<void> _evaluate() async {
    if (_disposed || _evaluating) return;

    final enabled =
        _preferences.getBool(AppConstants.prefNotificationsEnabled) ?? true;
    if (!enabled) return;

    final now = DateTime.now();
    final last = _lastRun;
    if (last != null && now.difference(last) < _minInterval) return;
    _lastRun = now;

    if (_tasks.isEmpty) return;

    final notifyDue =
        _preferences.getBool(AppConstants.prefNotifyDueDates) ?? true;
    final notifyPriority =
        _preferences.getBool(AppConstants.prefNotifyPriority) ?? true;

    final candidates = buildTaskNotifications(_tasks, now: now)
        .where(
          (notification) => notification.kind == TaskNotificationKind.priority
              ? notifyPriority
              : notifyDue,
        )
        .toList();
    if (candidates.isEmpty) return;

    _evaluating = true;
    try {
      final history = await _readHistory();
      var changed = false;

      for (final notification in candidates) {
        final previous = history[notification.dedupeKey];
        if (previous != null &&
            now.millisecondsSinceEpoch - previous <
                notification.repeatAfter.inMilliseconds) {
          continue;
        }

        final shown = await _notifications.show(notification);
        if (!shown) continue;

        history[notification.dedupeKey] = now.millisecondsSinceEpoch;
        changed = true;
      }

      if (changed) await _writeHistory(history, now);
    } catch (error) {
      debugPrint('No se pudieron evaluar las notificaciones: $error');
    } finally {
      _evaluating = false;
    }
  }

  Future<Map<String, int>> _readHistory() async {
    final file = _historyFile;
    if (file == null) return {};
    try {
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value is int ? value : int.tryParse('$value') ?? 0,
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeHistory(Map<String, int> history, DateTime now) async {
    final file = _historyFile;
    if (file == null) return;
    final cutoff = now.subtract(_historyRetention).millisecondsSinceEpoch;
    history.removeWhere((_, timestamp) => timestamp < cutoff);
    try {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(history), flush: true);
      await temporary.rename(file.path);
    } catch (error) {
      debugPrint('No se pudo guardar el historial de notificaciones: $error');
    }
  }
}
