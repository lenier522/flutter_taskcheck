import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> rowCount(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS total FROM $table')
        .getSingle();
    return row.read<int>('total');
  }

  test('clearAllData elimina tareas, subtareas y categorías', () async {
    final now = DateTime.now();
    await db.insertTask(
      Task(
        id: 'task-clear-1',
        title: 'Tarea con subtarea',
        status: TaskStatus.completed,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
        subtasks: [
          Subtask(
            id: 'subtask-clear-1',
            taskId: 'task-clear-1',
            title: 'Subtarea',
            createdAt: now,
          ),
        ],
      ),
    );

    expect(await rowCount('tasks'), 1);
    expect(await rowCount('subtasks'), 1);

    await db.clearAllData();

    expect(await rowCount('tasks'), 0);
    expect(await rowCount('subtasks'), 0);
    expect(await db.getTaskById('task-clear-1'), isNull);
  });

  test('clearAllData restaura las categorías por defecto', () async {
    final now = DateTime.now();
    await db.insertTask(
      Task(
        id: 'task-clear-2',
        title: 'Tarea archivada',
        isArchived: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.clearAllData();

    final categories = await db.getAllCategories();
    expect(categories, hasLength(4));
    expect(categories.any((c) => c.name == 'Programación'), isTrue);
    expect(categories.any((c) => c.name == 'Personal'), isTrue);
    // Archived tasks are data too, so they must be removed.
    expect(await rowCount('tasks'), 0);
  });
}
