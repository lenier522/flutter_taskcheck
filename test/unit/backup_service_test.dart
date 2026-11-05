import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/features/backup/data/backup_service.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

void main() {
  late AppDatabase db;
  late BackupService service;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
    tempDir = await Directory.systemTemp.createTemp('taskcheck_backup_test');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('exporta y restaura tareas, subtareas y categorías', () async {
    final now = DateTime(2026, 3, 14, 9, 30);
    await db.insertCategory(
      Category(
        id: 'cat-1',
        name: 'Trabajo',
        colorValue: 0xFF10B981,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.insertTask(
      Task(
        id: 'task-1',
        title: 'Preparar informe',
        description: 'Con gráficos',
        priority: TaskPriority.high,
        status: TaskStatus.completed,
        categoryId: 'cat-1',
        dueDate: now.add(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
        completedAt: now,
        subtasks: [
          Subtask(
            id: 'sub-1',
            taskId: 'task-1',
            title: 'Reunir datos',
            isCompleted: true,
            createdAt: now,
            completedAt: now,
          ),
        ],
      ),
    );

    final filePath = '${tempDir.path}/copia.json';
    final exported = await service.exportTo(filePath);
    expect(exported.tasks, 1);
    expect(exported.subtasks, 1);
    expect(File(filePath).existsSync(), isTrue);

    await db.clearAllData();
    expect(await db.getAllTasksWithDetails(), isEmpty);

    final restored = await service.restoreFrom(filePath);
    expect(restored.tasks, 1);
    // La copia incluye también las categorías por defecto de la app.
    expect(restored.categories, exported.categories);
    expect(restored.subtasks, 1);

    final tasks = await db.getAllTasksWithDetails();
    expect(tasks, hasLength(1));
    final task = tasks.single;
    expect(task.id, 'task-1');
    expect(task.title, 'Preparar informe');
    expect(task.description, 'Con gráficos');
    expect(task.priority, TaskPriority.high);
    expect(task.status, TaskStatus.completed);
    expect(task.completedAt, now);
    expect(task.dueDate, now.add(const Duration(days: 2)));
    expect(task.category?.name, 'Trabajo');
    expect(task.subtasks.single.title, 'Reunir datos');
    expect(task.subtasks.single.isCompleted, isTrue);
  });

  test('conserva las tareas archivadas en la copia', () async {
    final now = DateTime(2026, 5, 1);
    await db.insertTask(
      Task(
        id: 'task-archived',
        title: 'Vieja',
        createdAt: now,
        updatedAt: now,
        isArchived: true,
      ),
    );

    final filePath = '${tempDir.path}/copia.json';
    await service.exportTo(filePath);
    await service.restoreFrom(filePath);

    final tasks = await db.getAllTasksWithDetails();
    expect(tasks.single.isArchived, isTrue);
  });

  test('descarta tareas sin título y categorías inexistentes', () async {
    final file = File('${tempDir.path}/parcial.json');
    await file.writeAsString('''
{
  "signature": "task_check_backup",
  "formatVersion": 1,
  "categories": [{"id": "cat-1", "name": "Personal", "color": 4283066102}],
  "tasks": [
    {"id": "t1", "title": "  ", "categoryId": "cat-1"},
    {"id": "t2", "title": "Válida", "categoryId": "cat-inexistente"},
    {"id": "t2", "title": "Duplicada", "categoryId": "cat-1"}
  ]
}
''');

    final result = await service.restoreFrom(file.path);
    expect(result.tasks, 1);

    final tasks = await db.getAllTasksWithDetails();
    expect(tasks.single.title, 'Válida');
    expect(tasks.single.categoryId, isNull);
  });

  test('rechaza archivos ajenos a TaskCheck', () async {
    final file = File('${tempDir.path}/otro.json');
    await file.writeAsString('{"hola": 1}');

    await expectLater(
      service.restoreFrom(file.path),
      throwsA(isA<StorageException>()),
    );
  });

  test('rechaza JSON inválido y archivos inexistentes', () async {
    final file = File('${tempDir.path}/roto.json');
    await file.writeAsString('{ esto no es json ');

    await expectLater(
      service.restoreFrom(file.path),
      throwsA(isA<StorageException>()),
    );
    await expectLater(
      service.restoreFrom('${tempDir.path}/no-existe.json'),
      throwsA(isA<StorageException>()),
    );
  });
}
