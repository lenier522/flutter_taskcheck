import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_repository.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

class TaskRepositoryImpl implements TaskRepository {
  final AppDatabase _db;

  TaskRepositoryImpl(this._db);

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
  Stream<List<Task>> watchTasks({
    bool? isArchived,
    TaskStatus? status,
    TaskPriority? priority,
    String? categoryId,
    String? searchQuery,
  }) {
    return _db.watchTasksWithDetails(
      isArchived: isArchived,
      status: status,
      priority: priority,
      categoryId: categoryId,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<Task?> getTaskById(String id) {
    return _db.getTaskById(id);
  }

  @override
  Future<void> createTask(Task task) async {
    await _db.insertTask(task);
    await _notifySync();
  }

  @override
  Future<void> updateTask(Task task) async {
    await _db.updateTask(task);
    await _notifySync();
  }

  @override
  Future<void> setTaskStatus(String taskId, TaskStatus status) async {
    await _db.setTaskStatus(taskId, status);
    await _notifySync();
  }

  @override
  Future<void> setTaskArchived(String taskId, bool isArchived) async {
    await _db.setTaskArchived(taskId, isArchived);
    await _notifySync();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _db.deleteTask(taskId);
    await _notifySync();
  }
}
