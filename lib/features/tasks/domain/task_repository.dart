import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

abstract class TaskRepository {
  Stream<List<Task>> watchTasks({
    bool? isArchived,
    TaskStatus? status,
    TaskPriority? priority,
    String? categoryId,
    String? searchQuery,
  });

  Future<Task?> getTaskById(String id);
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> setTaskStatus(String taskId, TaskStatus status);
  Future<void> setTaskArchived(String taskId, bool isArchived);
  Future<void> deleteTask(String taskId);
}
