import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/subtasks/domain/subtask_repository.dart';

class SubtaskRepositoryImpl implements SubtaskRepository {
  final AppDatabase _db;

  SubtaskRepositoryImpl(this._db);

  Future<void> _notifySync() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'sync_signal'));
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString('${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {}
  }

  @override
  Stream<List<Subtask>> watchSubtasksForTask(String taskId) {
    return _db.watchSubtasksForTask(taskId);
  }

  @override
  Future<void> addSubtask(Subtask subtask) async {
    await _db.insertSubtask(subtask);
    await _notifySync();
  }

  @override
  Future<void> updateSubtask(Subtask subtask) async {
    await _db.updateSubtask(subtask);
    await _notifySync();
  }

  @override
  Future<void> setSubtaskCompleted(String subtaskId, bool isCompleted) async {
    await _db.setSubtaskCompleted(subtaskId, isCompleted);
    await _notifySync();
  }

  @override
  Future<void> deleteSubtask(String subtaskId) async {
    await _db.deleteSubtask(subtaskId);
    await _notifySync();
  }
}
