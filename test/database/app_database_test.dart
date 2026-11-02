import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Drift SQLite Tests', () {
    test('Database initializes and seeds default categories', () async {
      final categories = await db.getAllCategories();
      expect(categories, isNotEmpty);
      expect(categories.any((c) => c.name == 'Programación'), isTrue);
    });

    test('Can create, retrieve, and delete categories', () async {
      final now = DateTime.now();
      final cat = Category(
        id: 'cat-test-1',
        name: 'Diseño UX',
        colorValue: 0xFF9333EA,
        createdAt: now,
        updatedAt: now,
      );

      await db.insertCategory(cat);
      final categories = await db.getAllCategories();
      expect(categories.any((c) => c.id == 'cat-test-1'), isTrue);

      await db.deleteCategory('cat-test-1');
      final updated = await db.getAllCategories();
      expect(updated.any((c) => c.id == 'cat-test-1'), isFalse);
    });

    test('Can create, retrieve, update, and delete tasks', () async {
      final now = DateTime.now();
      final task = Task(
        id: 'task-test-1',
        title: 'Implementar pruebas',
        description: 'Escribir tests unitarios y de base de datos',
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      await db.insertTask(task);
      final retrieved = await db.getTaskById('task-test-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Implementar pruebas');
      expect(retrieved.priority, TaskPriority.high);
      expect(retrieved.status, TaskStatus.pending);

      // Complete task
      await db.setTaskStatus('task-test-1', TaskStatus.completed);
      final completed = await db.getTaskById('task-test-1');
      expect(completed!.status, TaskStatus.completed);
      expect(completed.completedAt, isNotNull);

      // Delete task
      await db.deleteTask('task-test-1');
      final deleted = await db.getTaskById('task-test-1');
      expect(deleted, isNull);
    });

    test(
      'Can create and toggle subtasks, and cascade delete on task removal',
      () async {
        final now = DateTime.now();
        final task = Task(
          id: 'task-test-2',
          title: 'Tarea con subtareas',
          createdAt: now,
          updatedAt: now,
        );
        await db.insertTask(task);

        final subtask1 = Subtask(
          id: 'sub-test-1',
          taskId: 'task-test-2',
          title: 'Subtarea A',
          isCompleted: false,
          createdAt: now,
        );
        final subtask2 = Subtask(
          id: 'sub-test-2',
          taskId: 'task-test-2',
          title: 'Subtarea B',
          isCompleted: false,
          createdAt: now,
        );

        await db.insertSubtask(subtask1);
        await db.insertSubtask(subtask2);

        var subtasks = await db.getSubtasksForTask('task-test-2');
        expect(subtasks.length, 2);

        // Toggle completion
        await db.setSubtaskCompleted('sub-test-1', true);
        subtasks = await db.getSubtasksForTask('task-test-2');
        expect(
          subtasks.firstWhere((s) => s.id == 'sub-test-1').isCompleted,
          isTrue,
        );

        // Delete parent task -> cascade delete subtasks
        await db.deleteTask('task-test-2');
        final remainingSubtasks = await db.getSubtasksForTask('task-test-2');
        expect(remainingSubtasks, isEmpty);
      },
    );

    test('Deleting a category sets task categoryId to null (FK ON DELETE SET NULL)', () async {
      final now = DateTime.now();
      final cat = Category(
        id: 'cat-to-delete',
        name: 'Temporal',
        colorValue: 0xFF123456,
        createdAt: now,
        updatedAt: now,
      );
      await db.insertCategory(cat);

      final task = Task(
        id: 'task-with-cat',
        title: 'Tarea asignada a categoria',
        categoryId: 'cat-to-delete',
        createdAt: now,
        updatedAt: now,
      );
      await db.insertTask(task);

      final before = await db.getTaskById('task-with-cat');
      expect(before!.categoryId, 'cat-to-delete');

      // Delete category
      await db.deleteCategory('cat-to-delete');
      final after = await db.getTaskById('task-with-cat');
      expect(after, isNotNull);
      expect(after!.categoryId, isNull);
    });

    test('watchTasksWithDetails streams tasks matching filters', () async {
      final now = DateTime.now();
      final t1 = Task(
        id: 't-stream-1',
        title: 'Comprar leche',
        priority: TaskPriority.low,
        createdAt: now,
        updatedAt: now,
      );
      final t2 = Task(
        id: 't-stream-2',
        title: 'Comprar pan',
        priority: TaskPriority.urgent,
        createdAt: now,
        updatedAt: now,
      );
      await db.insertTask(t1);
      await db.insertTask(t2);

      final allActive = await db.watchTasksWithDetails(isArchived: false).first;
      expect(allActive.any((t) => t.id == 't-stream-1'), isTrue);
      expect(allActive.any((t) => t.id == 't-stream-2'), isTrue);

      final urgentOnly = await db
          .watchTasksWithDetails(
            priority: TaskPriority.urgent,
            isArchived: false,
          )
          .first;
      expect(urgentOnly.length, 1);
      expect(urgentOnly.first.id, 't-stream-2');

      final searchResults = await db
          .watchTasksWithDetails(searchQuery: 'leche', isArchived: false)
          .first;
      expect(searchResults.length, 1);
      expect(searchResults.first.id, 't-stream-1');
    });

    test('Completed tasks older than 4 hours reject edits, status changes, '
        'subtask changes and deletion', () async {
      final old = DateTime.now().subtract(const Duration(hours: 5));
      final task = Task(
        id: 'task-locked',
        title: 'Tarea bloqueada',
        status: TaskStatus.completed,
        createdAt: old,
        updatedAt: old,
        completedAt: old,
      );
      await db.insertTask(task);

      await expectLater(
        db.updateTask(task.copyWith(title: 'Intento de edición')),
        throwsA(isA<TaskLockedException>()),
      );
      await expectLater(
        db.setTaskStatus('task-locked', TaskStatus.pending),
        throwsA(isA<TaskLockedException>()),
      );
      // Archiving is always allowed, even after the 4-hour window.
      await db.setTaskArchived('task-locked', true);
      expect((await db.getTaskById('task-locked'))!.isArchived, isTrue);
      await db.setTaskArchived('task-locked', false);
      expect((await db.getTaskById('task-locked'))!.isArchived, isFalse);
      await expectLater(
        db.deleteTask('task-locked'),
        throwsA(isA<TaskLockedException>()),
      );
      await expectLater(
        db.insertSubtask(
          Subtask(
            id: 'sub-locked',
            taskId: 'task-locked',
            title: 'Subtarea tardía',
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<TaskLockedException>()),
      );

      final unchanged = await db.getTaskById('task-locked');
      expect(unchanged, isNotNull);
      expect(unchanged!.title, 'Tarea bloqueada');
      expect(unchanged.status, TaskStatus.completed);
    });

    test('Completed tasks inside the 4-hour window can still be edited and '
        'deleted', () async {
      final completedAt = DateTime.now().subtract(const Duration(hours: 1));
      final task = Task(
        id: 'task-inside-window',
        title: 'Recién completada',
        status: TaskStatus.completed,
        createdAt: completedAt,
        updatedAt: completedAt,
        completedAt: completedAt,
      );
      await db.insertTask(task);

      await db.updateTask(task.copyWith(title: 'Editada a tiempo'));
      final edited = await db.getTaskById('task-inside-window');
      expect(edited, isNotNull);
      expect(edited!.title, 'Editada a tiempo');
      expect(edited.completedAt, isNotNull);

      await db.deleteTask('task-inside-window');
      expect(await db.getTaskById('task-inside-window'), isNull);
    });
  });
}
