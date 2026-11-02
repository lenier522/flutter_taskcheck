import 'package:task_check/features/subtasks/domain/subtask.dart';

abstract class SubtaskRepository {
  Stream<List<Subtask>> watchSubtasksForTask(String taskId);
  Future<void> addSubtask(Subtask subtask);
  Future<void> updateSubtask(Subtask subtask);
  Future<void> setSubtaskCompleted(String subtaskId, bool isCompleted);
  Future<void> deleteSubtask(String subtaskId);
}
