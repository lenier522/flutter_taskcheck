import 'package:drift/drift.dart';
import 'package:task_check/core/database/connection/connection.dart';
import 'package:task_check/core/database/tables.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [TasksTable, SubtasksTable, CategoriesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 2;

  /// Notifies Drift that external processes (like the main app or widget) may have
  /// modified tables on disk, causing all active watch queries to re-evaluate against SQLite.
  void syncFromDisk() {
    notifyUpdates({
      TableUpdate.onTable(tasksTable),
      TableUpdate.onTable(subtasksTable),
      TableUpdate.onTable(categoriesTable),
    });
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Seed initial categories
      await _seedInitialCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // 1.0.0 databases were created without completed_at but kept
        // schema version 1. Add the column only when it is really missing so
        // the 4-hour lock has a reliable reference without losing data.
        final taskColumns = await customSelect('PRAGMA table_info(tasks)')
            .get();
        if (!taskColumns.any(
          (row) => row.read<String>('name') == 'completed_at',
        )) {
          await m.addColumn(tasksTable, tasksTable.completedAt);
        }

        final subtaskColumns = await customSelect('PRAGMA table_info(subtasks)')
            .get();
        if (!subtaskColumns.any(
          (row) => row.read<String>('name') == 'completed_at',
        )) {
          await m.addColumn(subtasksTable, subtasksTable.completedAt);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      // Backfill completed_at for old completed tasks so the 4-hour edit
      // window has a reliable reference point.
      await customStatement(
        'UPDATE tasks SET completed_at = updated_at '
        'WHERE status = ? AND completed_at IS NULL',
        [TaskStatus.completed.value],
      );
    },
  );

  Future<void> _seedInitialCategories() async {
    const uuid = Uuid();
    final now = DateTime.now();
    final defaults = [
      CategoriesTableCompanion(
        id: Value(uuid.v4()),
        name: const Value('Programación'),
        color: const Value(0xFF3B82F6), // Blue
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      CategoriesTableCompanion(
        id: Value(uuid.v4()),
        name: const Value('Trabajo'),
        color: const Value(0xFF10B981), // Emerald Green
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      CategoriesTableCompanion(
        id: Value(uuid.v4()),
        name: const Value('Personal'),
        color: const Value(0xFF8B5CF6), // Purple
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      CategoriesTableCompanion(
        id: Value(uuid.v4()),
        name: const Value('Estudios'),
        color: const Value(0xFFF59E0B), // Amber
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    ];
    await batch((b) {
      b.insertAll(categoriesTable, defaults);
    });
  }

  // ================= CATEGORIES =================
  Stream<List<Category>> watchCategories() {
    return select(categoriesTable)
        .watch()
        .map((rows) => rows.map(_mapCategoryEntityToDomain).toList());
  }

  Future<List<Category>> getAllCategories() async {
    final rows = await select(categoriesTable).get();
    return rows.map(_mapCategoryEntityToDomain).toList();
  }

  Future<Category?> getCategoryById(String id) async {
    final query = select(categoriesTable)..where((tbl) => tbl.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _mapCategoryEntityToDomain(row) : null;
  }

  Future<void> insertCategory(Category category) async {
    await into(categoriesTable).insert(
      CategoriesTableCompanion(
        id: Value(category.id),
        name: Value(category.name),
        color: Value(category.colorValue),
        createdAt: Value(category.createdAt),
        updatedAt: Value(category.updatedAt),
      ),
    );
  }

  Future<void> updateCategory(Category category) async {
    await (update(
      categoriesTable,
    )..where((tbl) => tbl.id.equals(category.id))).write(
      CategoriesTableCompanion(
        name: Value(category.name),
        color: Value(category.colorValue),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteCategory(String id) async {
    await transaction(() async {
      // Safe policy: update tasks referencing this category to null
      await (update(tasksTable)..where((tbl) => tbl.categoryId.equals(id)))
          .write(const TasksTableCompanion(categoryId: Value(null)));
      // Delete category
      await (delete(categoriesTable)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  // ================= TASKS =================
  Stream<List<Task>> watchTasksWithDetails({
    bool? isArchived,
    TaskStatus? status,
    TaskPriority? priority,
    String? categoryId,
    String? searchQuery,
  }) {
    // Reactive stream combining tasks, categories, and subtasks
    final query = select(tasksTable).join([
      leftOuterJoin(
        categoriesTable,
        categoriesTable.id.equalsExp(tasksTable.categoryId),
      ),
    ]);

    if (isArchived != null) {
      query.where(tasksTable.isArchived.equals(isArchived));
    }
    if (status != null) {
      query.where(tasksTable.status.equals(status.value));
    }
    if (priority != null) {
      query.where(tasksTable.priority.equals(priority.value));
    }
    if (categoryId != null) {
      query.where(tasksTable.categoryId.equals(categoryId));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where(
        tasksTable.title.lower().like(term) |
            (tasksTable.description.isNotNull() &
                tasksTable.description.lower().like(term)),
      );
    }

    query.orderBy([
      OrderingTerm(expression: tasksTable.sortOrder, mode: OrderingMode.asc),
      OrderingTerm(expression: tasksTable.createdAt, mode: OrderingMode.desc),
    ]);

    return query.watch().asyncMap((rows) async {
      final result = <Task>[];
      for (final row in rows) {
        final taskEntity = row.readTable(tasksTable);
        final categoryEntity = row.readTableOrNull(categoriesTable);
        final subtasksRows =
            await (select(subtasksTable)
                  ..where((tbl) => tbl.taskId.equals(taskEntity.id))
                  ..orderBy([
                    (s) => OrderingTerm(
                      expression: s.sortOrder,
                      mode: OrderingMode.asc,
                    ),
                  ]))
                .get();

        final domainCategory = categoryEntity != null
            ? _mapCategoryEntityToDomain(categoryEntity)
            : null;
        final domainSubtasks = subtasksRows
            .map(_mapSubtaskEntityToDomain)
            .toList();

        result.add(
          _mapTaskEntityToDomain(
            taskEntity,
            category: domainCategory,
            subtasks: domainSubtasks,
          ),
        );
      }
      return result;
    });
  }

  Future<Task?> getTaskById(String id) async {
    final query = select(tasksTable).join([
      leftOuterJoin(
        categoriesTable,
        categoriesTable.id.equalsExp(tasksTable.categoryId),
      ),
    ])..where(tasksTable.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final taskEntity = row.readTable(tasksTable);
    final categoryEntity = row.readTableOrNull(categoriesTable);
    final subtasksRows =
        await (select(subtasksTable)
              ..where((tbl) => tbl.taskId.equals(taskEntity.id))
              ..orderBy([
                (s) => OrderingTerm(
                  expression: s.sortOrder,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();

    return _mapTaskEntityToDomain(
      taskEntity,
      category: categoryEntity != null
          ? _mapCategoryEntityToDomain(categoryEntity)
          : null,
      subtasks: subtasksRows.map(_mapSubtaskEntityToDomain).toList(),
    );
  }

  Future<void> insertTask(Task task) async {
    await transaction(() async {
      await into(tasksTable).insert(
        TasksTableCompanion(
          id: Value(task.id),
          title: Value(task.title.trim()),
          description: Value(task.description?.trim()),
          priority: Value(task.priority.value),
          status: Value(task.status.value),
          categoryId: Value(task.categoryId),
          dueDate: Value(task.dueDate),
          createdAt: Value(task.createdAt),
          updatedAt: Value(task.updatedAt),
          completedAt: Value(task.completedAt),
          isArchived: Value(task.isArchived),
          sortOrder: Value(task.sortOrder),
        ),
      );

      for (final subtask in task.subtasks) {
        await into(subtasksTable).insert(
          SubtasksTableCompanion(
            id: Value(subtask.id),
            taskId: Value(task.id),
            title: Value(subtask.title.trim()),
            isCompleted: Value(subtask.isCompleted),
            createdAt: Value(subtask.createdAt),
            completedAt: Value(subtask.completedAt),
            sortOrder: Value(subtask.sortOrder),
          ),
        );
      }
    });
  }

  Future<void> updateTask(Task task) async {
    final existing = await _getTaskEntity(task.id);
    if (existing == null) return;
    _ensureTaskCanBeModified(existing);

    final now = DateTime.now();
    final isCompleted = task.status == TaskStatus.completed;
    final DateTime? completedAt;
    if (isCompleted) {
      // Preserve the original completion time while the task remains
      // completed; otherwise start the 4-hour window now.
      completedAt = existing.status == TaskStatus.completed.value
          ? (existing.completedAt ?? existing.updatedAt)
          : now;
    } else {
      completedAt = null;
    }

    await (update(tasksTable)..where((tbl) => tbl.id.equals(task.id))).write(
      TasksTableCompanion(
        title: Value(task.title.trim()),
        description: Value(task.description?.trim()),
        priority: Value(task.priority.value),
        status: Value(task.status.value),
        categoryId: Value(task.categoryId),
        dueDate: Value(task.dueDate),
        updatedAt: Value(now),
        completedAt: Value(completedAt),
        isArchived: Value(task.isArchived),
        sortOrder: Value(task.sortOrder),
      ),
    );
  }

  Future<void> setTaskStatus(String taskId, TaskStatus status) async {
    final existing = await _getTaskEntity(taskId);
    if (existing == null) return;
    _ensureTaskCanBeModified(existing);

    final now = DateTime.now();
    final isCompleted = status == TaskStatus.completed;
    final DateTime? completedAt;
    if (isCompleted) {
      completedAt = existing.status == TaskStatus.completed.value
          ? (existing.completedAt ?? existing.updatedAt)
          : now;
    } else {
      completedAt = null;
    }

    await (update(tasksTable)..where((tbl) => tbl.id.equals(taskId))).write(
      TasksTableCompanion(
        status: Value(status.value),
        completedAt: Value(completedAt),
        updatedAt: Value(now),
      ),
    );
  }

  /// Archivar o restaurar una tarea siempre está permitido: el bloqueo de las
  /// 4 horas aplica a la edición y al borrado, nunca al archivado.
  Future<void> setTaskArchived(String taskId, bool isArchived) async {
    await (update(tasksTable)..where((tbl) => tbl.id.equals(taskId))).write(
      TasksTableCompanion(
        isArchived: Value(isArchived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Devuelve todas las tareas (incluidas las archivadas) con su categoría y
  /// subtareas, sin filtros. Se usa para la copia de seguridad.
  Future<List<Task>> getAllTasksWithDetails() async {
    final rows =
        await (select(tasksTable).join([
              leftOuterJoin(
                categoriesTable,
                categoriesTable.id.equalsExp(tasksTable.categoryId),
              ),
            ])..orderBy([
              OrderingTerm(
                expression: tasksTable.sortOrder,
                mode: OrderingMode.asc,
              ),
            ]))
            .get();

    final result = <Task>[];
    for (final row in rows) {
      final taskEntity = row.readTable(tasksTable);
      final categoryEntity = row.readTableOrNull(categoriesTable);
      final subtasksRows =
          await (select(subtasksTable)
                ..where((tbl) => tbl.taskId.equals(taskEntity.id))
                ..orderBy([
                  (s) => OrderingTerm(
                    expression: s.sortOrder,
                    mode: OrderingMode.asc,
                  ),
                ]))
              .get();

      result.add(
        _mapTaskEntityToDomain(
          taskEntity,
          category: categoryEntity != null
              ? _mapCategoryEntityToDomain(categoryEntity)
              : null,
          subtasks: subtasksRows.map(_mapSubtaskEntityToDomain).toList(),
        ),
      );
    }
    return result;
  }

  Future<void> deleteTask(String taskId) async {
    await _ensureTaskCanBeModifiedById(taskId);
    await transaction(() async {
      await (delete(
        subtasksTable,
      )..where((tbl) => tbl.taskId.equals(taskId))).go();
      await (delete(tasksTable)..where((tbl) => tbl.id.equals(taskId))).go();
    });
  }

  Future<TaskEntity?> _getTaskEntity(String taskId) {
    return (select(
      tasksTable,
    )..where((tbl) => tbl.id.equals(taskId))).getSingleOrNull();
  }

  Future<void> _ensureTaskCanBeModifiedById(String taskId) async {
    final task = await _getTaskEntity(taskId);
    if (task != null) _ensureTaskCanBeModified(task);
  }

  void _ensureTaskCanBeModified(TaskEntity task) {
    if (task.status != TaskStatus.completed.value) return;

    final completedAt = task.completedAt ?? task.updatedAt;
    final deadline = completedAt.add(Task.completionEditWindow);
    if (!DateTime.now().isBefore(deadline)) {
      throw const TaskLockedException();
    }
  }

  /// Elimina todas las tareas, subtareas y categorías del usuario y vuelve a
  /// dejar las categorías por defecto, sin tocar las preferencias de la app.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(subtasksTable).go();
      await delete(tasksTable).go();
      await delete(categoriesTable).go();
      await _seedInitialCategories();
    });
    syncFromDisk();
  }

  /// Reemplaza todo el contenido de la base de datos por el de una copia de
  /// seguridad. No aplica el bloqueo de las 4 horas: restaurar un respaldo es
  /// una operación de recuperación, no una edición de tareas.
  Future<void> replaceAllData({
    required List<Category> categories,
    required List<Task> tasks,
  }) async {
    await transaction(() async {
      await delete(subtasksTable).go();
      await delete(tasksTable).go();
      await delete(categoriesTable).go();

      for (final category in categories) {
        await insertCategory(category);
      }
      for (final task in tasks) {
        await insertTask(task);
      }
    });
    syncFromDisk();
  }

  // ================= SUBTASKS =================
  Stream<List<Subtask>> watchSubtasksForTask(String taskId) {
    return (select(subtasksTable)
          ..where((tbl) => tbl.taskId.equals(taskId))
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.sortOrder, mode: OrderingMode.asc),
          ]))
        .watch()
        .map((rows) => rows.map(_mapSubtaskEntityToDomain).toList());
  }

  Future<List<Subtask>> getSubtasksForTask(String taskId) async {
    final rows =
        await (select(subtasksTable)
              ..where((tbl) => tbl.taskId.equals(taskId))
              ..orderBy([
                (s) => OrderingTerm(
                  expression: s.sortOrder,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();
    return rows.map(_mapSubtaskEntityToDomain).toList();
  }

  Future<void> insertSubtask(Subtask subtask) async {
    await _ensureTaskCanBeModifiedById(subtask.taskId);
    await into(subtasksTable).insert(
      SubtasksTableCompanion(
        id: Value(subtask.id),
        taskId: Value(subtask.taskId),
        title: Value(subtask.title.trim()),
        isCompleted: Value(subtask.isCompleted),
        createdAt: Value(subtask.createdAt),
        completedAt: Value(subtask.completedAt),
        sortOrder: Value(subtask.sortOrder),
      ),
    );
    // Touch task updated_at
    await (update(tasksTable)..where((tbl) => tbl.id.equals(subtask.taskId)))
        .write(TasksTableCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> updateSubtask(Subtask subtask) async {
    final existing = await (select(
      subtasksTable,
    )..where((tbl) => tbl.id.equals(subtask.id))).getSingleOrNull();
    if (existing == null) return;
    await _ensureTaskCanBeModifiedById(existing.taskId);

    await (update(
      subtasksTable,
    )..where((tbl) => tbl.id.equals(subtask.id))).write(
      SubtasksTableCompanion(
        title: Value(subtask.title.trim()),
        isCompleted: Value(subtask.isCompleted),
        completedAt: Value(subtask.completedAt),
        sortOrder: Value(subtask.sortOrder),
      ),
    );
    // Touch task updated_at
    await (update(tasksTable)..where((tbl) => tbl.id.equals(subtask.taskId)))
        .write(TasksTableCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> setSubtaskCompleted(String subtaskId, bool isCompleted) async {
    final now = DateTime.now();
    final row = await (select(
      subtasksTable,
    )..where((tbl) => tbl.id.equals(subtaskId))).getSingleOrNull();
    if (row == null) return;
    await _ensureTaskCanBeModifiedById(row.taskId);

    await (update(
      subtasksTable,
    )..where((tbl) => tbl.id.equals(subtaskId))).write(
      SubtasksTableCompanion(
        isCompleted: Value(isCompleted),
        completedAt: Value(isCompleted ? now : null),
      ),
    );
    await (update(tasksTable)..where((tbl) => tbl.id.equals(row.taskId))).write(
      TasksTableCompanion(updatedAt: Value(now)),
    );
  }

  Future<void> deleteSubtask(String subtaskId) async {
    final row = await (select(
      subtasksTable,
    )..where((tbl) => tbl.id.equals(subtaskId))).getSingleOrNull();
    if (row != null) {
      await _ensureTaskCanBeModifiedById(row.taskId);
      await (delete(
        subtasksTable,
      )..where((tbl) => tbl.id.equals(subtaskId))).go();
      await (update(tasksTable)..where((tbl) => tbl.id.equals(row.taskId)))
          .write(TasksTableCompanion(updatedAt: Value(DateTime.now())));
    }
  }

  // ================= MAPPERS =================
  Category _mapCategoryEntityToDomain(CategoryEntity entity) {
    return Category(
      id: entity.id,
      name: entity.name,
      colorValue: entity.color,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Subtask _mapSubtaskEntityToDomain(SubtaskEntity entity) {
    return Subtask(
      id: entity.id,
      taskId: entity.taskId,
      title: entity.title,
      isCompleted: entity.isCompleted,
      createdAt: entity.createdAt,
      completedAt: entity.completedAt,
      sortOrder: entity.sortOrder,
    );
  }

  Task _mapTaskEntityToDomain(
    TaskEntity entity, {
    Category? category,
    List<Subtask> subtasks = const [],
  }) {
    return Task(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      priority: TaskPriority.fromValue(entity.priority),
      status: TaskStatus.fromValue(entity.status),
      categoryId: entity.categoryId,
      dueDate: entity.dueDate,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      completedAt: entity.completedAt,
      isArchived: entity.isArchived,
      sortOrder: entity.sortOrder,
      category: category,
      subtasks: subtasks,
    );
  }
}
