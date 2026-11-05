import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/services/task_notification_scheduler.dart';
import 'package:task_check/features/backup/data/backup_service.dart';
import 'package:task_check/features/categories/data/category_repository_impl.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/categories/domain/category_repository.dart';
import 'package:task_check/features/settings/data/preferences_repository.dart';
import 'package:task_check/features/subtasks/data/subtask_repository_impl.dart';
import 'package:task_check/features/subtasks/domain/subtask_repository.dart';
import 'package:task_check/features/tasks/data/task_repository_impl.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_repository.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

// SharedPreferences & Preferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be overridden in ProviderScope',
  );
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesRepository(prefs);
});

// Database
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Repositories
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TaskRepositoryImpl(db);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoryRepositoryImpl(db);
});

final subtaskRepositoryProvider = Provider<SubtaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SubtaskRepositoryImpl(db);
});

// Theme Mode Controller — uses Riverpod 3.x NotifierProvider
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final repo = ref.read(preferencesRepositoryProvider);
    return repo.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesRepositoryProvider).setThemeMode(mode);
  }
}

// Simple mutable state providers (Riverpod 3.x uses plain Provider + StateNotifier or just manual ref)
final searchQueryProvider = NotifierProvider<_StringNotifier, String>(
  _StringNotifier.new,
);
final selectedCategoryFilterProvider =
    NotifierProvider<_NullableStringNotifier, String?>(
      _NullableStringNotifier.new,
    );
final selectedPriorityFilterProvider =
    NotifierProvider<_PriorityNotifier, TaskPriority?>(_PriorityNotifier.new);
final selectedStatusFilterProvider =
    NotifierProvider<_StatusNotifier, TaskStatus?>(_StatusNotifier.new);

class _StringNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

class _NullableStringNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

class _PriorityNotifier extends Notifier<TaskPriority?> {
  @override
  TaskPriority? build() => null;
  void set(TaskPriority? v) => state = v;
}

class _StatusNotifier extends Notifier<TaskStatus?> {
  @override
  TaskStatus? build() => null;
  void set(TaskStatus? v) => state = v;
}

// Data Streams
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchCategories();
});

// Main stream of all non-archived tasks
final allActiveTasksProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTasks(isArchived: false);
});

// Stream for archived tasks
final archivedTasksProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTasks(isArchived: true);
});

// Filtered tasks provider
final filteredTasksProvider = Provider<List<Task>>((ref) {
  final tasksAsync = ref.watch(allActiveTasksProvider);
  final tasks = tasksAsync.asData?.value ?? [];

  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final catId = ref.watch(selectedCategoryFilterProvider);
  final priority = ref.watch(selectedPriorityFilterProvider);
  final status = ref.watch(selectedStatusFilterProvider);

  return tasks.where((t) {
    if (catId != null && t.categoryId != catId) return false;
    if (priority != null && t.priority != priority) return false;
    if (status != null && t.status != status) return false;
    if (query.isNotEmpty) {
      final inTitle = t.title.toLowerCase().contains(query);
      final inDesc = t.description?.toLowerCase().contains(query) ?? false;
      if (!inTitle && !inDesc) return false;
    }
    return true;
  }).toList();
});

// Counts for Sidebar Badges & Dashboard
final pendingTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(allActiveTasksProvider).asData?.value ?? [];
  return tasks.where((t) => t.status != TaskStatus.completed).length;
});

final todayTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(allActiveTasksProvider).asData?.value ?? [];
  return tasks.where((t) => t.isDueToday && !t.isCompleted).length;
});

final importantTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(allActiveTasksProvider).asData?.value ?? [];
  return tasks
      .where(
        (t) =>
            (t.priority == TaskPriority.high ||
                t.priority == TaskPriority.urgent) &&
            !t.isCompleted,
      )
      .length;
});

final inProgressTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(allActiveTasksProvider).asData?.value ?? [];
  return tasks.where((t) => t.status == TaskStatus.inProgress).length;
});

final completedTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(allActiveTasksProvider).asData?.value ?? [];
  return tasks.where((t) => t.status == TaskStatus.completed).length;
});

final archivedTasksCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(archivedTasksProvider).asData?.value ?? [];
  return tasks.length;
});

// System notifications: watches tasks and launches desktop notifications.
final taskNotificationSchedulerProvider = Provider<TaskNotificationScheduler>((
  ref,
) {
  final scheduler = TaskNotificationScheduler(
    ref.watch(appDatabaseProvider),
    ref.watch(sharedPreferencesProvider),
  );
  unawaited(scheduler.start());
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
