import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taskcheck_migration_');
    dbFile = File('${tempDir.path}/legacy.db');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Crea una base de datos con el esquema de la versión 1.0.0. Algunos
  /// builds antiguos no tenían `completed_at` pero mantenían user_version = 1.
  void createLegacyDatabase({required bool withCompletedAt}) {
    final raw = sqlite3.open(dbFile.path);
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
      CREATE TABLE categories (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE tasks (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        status INTEGER NOT NULL DEFAULT 0,
        category_id TEXT NULL REFERENCES categories (id) ON DELETE SET NULL,
        due_date INTEGER NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        ${withCompletedAt ? 'completed_at INTEGER NULL,' : ''}
        is_archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE subtasks (
        id TEXT NOT NULL PRIMARY KEY,
        task_id TEXT NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        ${withCompletedAt ? 'completed_at INTEGER NULL,' : ''}
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');

    final completedSeconds =
        DateTime.now()
            .subtract(const Duration(hours: 5))
            .millisecondsSinceEpoch ~/
        1000;
    raw.execute(
      'INSERT INTO tasks '
      '(id, title, priority, status, created_at, updated_at, is_archived, '
      'sort_order) VALUES (?, ?, 1, ?, ?, ?, 0, 0)',
      [
        'legacy-completed',
        'Tarea antigua',
        2,
        completedSeconds,
        completedSeconds,
      ],
    );
    raw.execute('PRAGMA user_version = 1;');
    raw.close();
  }

  test('Migrates a v1 database and enforces the 4-hour lock', () async {
    createLegacyDatabase(withCompletedAt: false);

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final task = await db.getTaskById('legacy-completed');
    expect(task, isNotNull);
    expect(task!.title, 'Tarea antigua');
    expect(task.status, TaskStatus.completed);
    expect(task.completedAt, isNotNull);
    expect(task.isCompletionLocked, isTrue);

    final subtaskColumns = await db
        .customSelect('PRAGMA table_info(subtasks)')
        .get();
    expect(
      subtaskColumns.any((row) => row.read<String>('name') == 'completed_at'),
      isTrue,
    );

    await expectLater(
      db.updateTask(task.copyWith(title: 'Intento de edición')),
      throwsA(isA<TaskLockedException>()),
    );
    await expectLater(
      db.deleteTask('legacy-completed'),
      throwsA(isA<TaskLockedException>()),
    );
  });

  test('Keeps a v1 database that already has completed_at', () async {
    createLegacyDatabase(withCompletedAt: true);

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final task = await db.getTaskById('legacy-completed');
    expect(task, isNotNull);
    expect(task!.status, TaskStatus.completed);
    expect(task.completedAt, isNotNull);
  });
}
