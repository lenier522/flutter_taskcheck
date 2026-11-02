import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

void main() {
  group('Task Domain Model Tests', () {
    final now = DateTime.now();

    test('Creates valid Task instance with default values', () {
      final task = Task(
        id: 't-1',
        title: 'Comprar café',
        createdAt: now,
        updatedAt: now,
      );

      expect(task.id, 't-1');
      expect(task.title, 'Comprar café');
      expect(task.priority, TaskPriority.normal);
      expect(task.status, TaskStatus.pending);
      expect(task.isArchived, isFalse);
      expect(task.isCompleted, isFalse);
      expect(task.completedAt, isNull);
      expect(task.subtasks, isEmpty);
      expect(task.progress, 0.0);
    });

    test('Progress calculation without subtasks', () {
      final pendingTask = Task(
        id: 't-2',
        title: 'Tarea pendiente',
        status: TaskStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      expect(pendingTask.progress, 0.0);

      final completedTask = Task(
        id: 't-3',
        title: 'Tarea completada',
        status: TaskStatus.completed,
        createdAt: now,
        updatedAt: now,
      );
      expect(completedTask.progress, 100.0);
    });

    test('Progress calculation with subtasks (0%, 50%, 100%)', () {
      final s1 = Subtask(
        id: 's-1',
        taskId: 't-4',
        title: 'Paso 1',
        isCompleted: false,
        createdAt: now,
      );
      final s2 = Subtask(
        id: 's-2',
        taskId: 't-4',
        title: 'Paso 2',
        isCompleted: false,
        createdAt: now,
      );

      final taskAllPending = Task(
        id: 't-4',
        title: 'Tarea con subtareas',
        createdAt: now,
        updatedAt: now,
        subtasks: [s1, s2],
      );
      expect(taskAllPending.totalSubtasks, 2);
      expect(taskAllPending.completedSubtasks, 0);
      expect(taskAllPending.progress, 0.0);

      final taskPartial = taskAllPending.copyWith(
        subtasks: [s1.copyWith(isCompleted: true), s2],
      );
      expect(taskPartial.completedSubtasks, 1);
      expect(taskPartial.progress, 50.0);

      final taskAllDone = taskAllPending.copyWith(
        subtasks: [
          s1.copyWith(isCompleted: true),
          s2.copyWith(isCompleted: true),
        ],
      );
      expect(taskAllDone.completedSubtasks, 2);
      expect(taskAllDone.progress, 100.0);
    });

    test('Overdue logic accurately detects past due date', () {
      final pastDate = now.subtract(const Duration(days: 2));
      final futureDate = now.add(const Duration(days: 2));

      final overdueTask = Task(
        id: 't-5',
        title: 'Tarea vencida',
        dueDate: pastDate,
        status: TaskStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      expect(overdueTask.isOverdue, isTrue);

      final notOverdueTask = Task(
        id: 't-6',
        title: 'Tarea a tiempo',
        dueDate: futureDate,
        status: TaskStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      expect(notOverdueTask.isOverdue, isFalse);

      final completedOverdueTask = overdueTask.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
      );
      expect(
        completedOverdueTask.isOverdue,
        isFalse,
        reason: 'Completed tasks must not be overdue',
      );

      final archivedOverdueTask = overdueTask.copyWith(isArchived: true);
      expect(
        archivedOverdueTask.isOverdue,
        isFalse,
        reason: 'Archived tasks must not be overdue',
      );
    });

    test('Due today logic detects tasks due on current date', () {
      final todayDate = DateTime(now.year, now.month, now.day, 23, 59);
      final tomorrowDate = DateTime(now.year, now.month, now.day + 1);

      final todayTask = Task(
        id: 't-7',
        title: 'Vence hoy',
        dueDate: todayDate,
        createdAt: now,
        updatedAt: now,
      );
      expect(todayTask.isDueToday, isTrue);

      final tomorrowTask = Task(
        id: 't-8',
        title: 'Vence mañana',
        dueDate: tomorrowDate,
        createdAt: now,
        updatedAt: now,
      );
      expect(tomorrowTask.isDueToday, isFalse);
    });

    test('copyWith works correctly for updating and clearing fields', () {
      final task = Task(
        id: 't-9',
        title: 'Original',
        categoryId: 'cat-1',
        createdAt: now,
        updatedAt: now,
      );

      final updated = task.copyWith(
        title: 'Actualizado',
        status: TaskStatus.inProgress,
        clearCategory: true,
      );

      expect(updated.id, 't-9');
      expect(updated.title, 'Actualizado');
      expect(updated.status, TaskStatus.inProgress);
      expect(updated.categoryId, isNull);
    });

    test('Completed tasks lock only after the 4-hour edit window', () {
      final recentlyCompleted = Task(
        id: 't-lock-1',
        title: 'Completada hace una hora',
        status: TaskStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        completedAt: now.subtract(const Duration(hours: 1)),
      );
      expect(recentlyCompleted.isCompletionLocked, isFalse);
      expect(recentlyCompleted.remainingEditTime, greaterThan(Duration.zero));

      final completedLongAgo = Task(
        id: 't-lock-2',
        title: 'Completada hace cinco horas',
        status: TaskStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 5)),
        completedAt: now.subtract(const Duration(hours: 5)),
      );
      expect(completedLongAgo.isCompletionLocked, isTrue);
      expect(completedLongAgo.remainingEditTime, Duration.zero);

      final pendingOldTask = Task(
        id: 't-lock-3',
        title: 'Pendiente antigua',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      );
      expect(pendingOldTask.isCompletionLocked, isFalse);
    });

    test('excludeCompletedTasks removes completed tasks from widget lists', () {
      final pending = Task(
        id: 't-filter-1',
        title: 'Pendiente',
        createdAt: now,
        updatedAt: now,
      );
      final inProgress = Task(
        id: 't-filter-2',
        title: 'En progreso',
        status: TaskStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      );
      final completed = Task(
        id: 't-filter-3',
        title: 'Completada',
        status: TaskStatus.completed,
        createdAt: now,
        updatedAt: now,
        completedAt: now,
      );

      final visible = excludeCompletedTasks([pending, inProgress, completed]);

      expect(visible.map((t) => t.id), ['t-filter-1', 't-filter-2']);
    });
  });
}
