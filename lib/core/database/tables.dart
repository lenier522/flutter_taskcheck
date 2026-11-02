import 'package:drift/drift.dart';

@DataClassName('CategoryEntity')
class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get color => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskEntity')
@TableIndex(name: 'idx_tasks_status', columns: {#status})
@TableIndex(name: 'idx_tasks_priority', columns: {#priority})
@TableIndex(name: 'idx_tasks_category_id', columns: {#categoryId})
@TableIndex(name: 'idx_tasks_due_date', columns: {#dueDate})
@TableIndex(name: 'idx_tasks_is_archived', columns: {#isArchived})
class TasksTable extends Table {
  @override
  String get tableName => 'tasks';

  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get categoryId =>
      text().nullable().references(CategoriesTable, #id)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SubtaskEntity')
@TableIndex(name: 'idx_subtasks_task_id', columns: {#taskId})
class SubtasksTable extends Table {
  @override
  String get tableName => 'subtasks';

  TextColumn get id => text()();
  TextColumn get taskId => text().references(TasksTable, #id)();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
