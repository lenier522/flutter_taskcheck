import 'dart:convert';
import 'dart:io';

import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

/// Resumen de una copia de seguridad guardada o restaurada.
class BackupResult {
  const BackupResult({
    required this.filePath,
    required this.categories,
    required this.tasks,
    required this.subtasks,
  });

  final String filePath;
  final int categories;
  final int tasks;
  final int subtasks;

  String get summary =>
      '$tasks ${tasks == 1 ? 'tarea' : 'tareas'}, '
      '$subtasks ${subtasks == 1 ? 'subtarea' : 'subtareas'} y '
      '$categories ${categories == 1 ? 'categoría' : 'categorías'}';
}

/// Exporta y restaura todas las tareas, subtareas y categorías en un archivo
/// JSON legible, independiente del archivo SQLite de la aplicación.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const String fileExtension = 'json';

  /// Marca que identifica los archivos generados por TaskCheck.
  static const String signature = 'task_check_backup';
  static const int formatVersion = 1;

  /// Nombre sugerido para el archivo de exportación.
  static String suggestedFileName([DateTime? now]) {
    final date = now ?? DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'taskcheck-copia-${date.year}${two(date.month)}${two(date.day)}'
        '-${two(date.hour)}${two(date.minute)}.$fileExtension';
  }

  /// Guarda todas las tareas (también las archivadas) en [filePath].
  Future<BackupResult> exportTo(String filePath) async {
    final categories = await _db.getAllCategories();
    final tasks = await _db.getAllTasksWithDetails();

    final payload = <String, dynamic>{
      'signature': signature,
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map(_categoryToJson).toList(),
      'tasks': tasks.map(_taskToJson).toList(),
    };

    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
    } catch (error, stackTrace) {
      throw StorageException(
        'No se pudo guardar la copia de seguridad en $filePath.',
        error,
        stackTrace,
      );
    }

    return BackupResult(
      filePath: filePath,
      categories: categories.length,
      tasks: tasks.length,
      subtasks: tasks.fold(0, (sum, task) => sum + task.subtasks.length),
    );
  }

  /// Reemplaza el contenido actual de la base de datos por el del archivo.
  Future<BackupResult> restoreFrom(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StorageException(
        'El archivo de copia de seguridad no existe: $filePath',
      );
    }

    final String raw;
    try {
      raw = await file.readAsString();
    } catch (error, stackTrace) {
      throw StorageException(
        'No se pudo leer el archivo de copia de seguridad.',
        error,
        stackTrace,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error, stackTrace) {
      throw StorageException(
        'El archivo no contiene un JSON válido.',
        error,
        stackTrace,
      );
    }

    if (decoded is! Map) {
      throw const StorageException(
        'El archivo no tiene el formato de una copia de seguridad de TaskCheck.',
      );
    }
    if (decoded['signature'] != signature) {
      throw const StorageException('El archivo no fue creado por TaskCheck.');
    }

    final categories = _parseCategories(decoded['categories']);
    final tasks = _parseTasks(decoded['tasks'], categories);

    await _db.replaceAllData(categories: categories, tasks: tasks);

    return BackupResult(
      filePath: filePath,
      categories: categories.length,
      tasks: tasks.length,
      subtasks: tasks.fold(0, (sum, task) => sum + task.subtasks.length),
    );
  }

  // ================= SERIALIZACIÓN =================
  Map<String, dynamic> _categoryToJson(Category category) => {
    'id': category.id,
    'name': category.name,
    'color': category.colorValue,
    'createdAt': category.createdAt.toIso8601String(),
    'updatedAt': category.updatedAt.toIso8601String(),
  };

  Map<String, dynamic> _taskToJson(Task task) => {
    'id': task.id,
    'title': task.title,
    'description': task.description,
    'priority': task.priority.value,
    'status': task.status.value,
    'categoryId': task.categoryId,
    'dueDate': task.dueDate?.toIso8601String(),
    'createdAt': task.createdAt.toIso8601String(),
    'updatedAt': task.updatedAt.toIso8601String(),
    'completedAt': task.completedAt?.toIso8601String(),
    'isArchived': task.isArchived,
    'sortOrder': task.sortOrder,
    'subtasks': task.subtasks.map(_subtaskToJson).toList(),
  };

  Map<String, dynamic> _subtaskToJson(Subtask subtask) => {
    'id': subtask.id,
    'title': subtask.title,
    'isCompleted': subtask.isCompleted,
    'createdAt': subtask.createdAt.toIso8601String(),
    'completedAt': subtask.completedAt?.toIso8601String(),
    'sortOrder': subtask.sortOrder,
  };

  // ================= LECTURA DEFENSIVA =================
  List<Category> _parseCategories(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const StorageException(
        'La copia de seguridad tiene un formato inválido en "categories".',
      );
    }

    final result = <Category>[];
    final seenIds = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final id = _asString(item['id']);
      if (id == null || !seenIds.add(id)) continue;

      final name = _asString(item['name'])?.trim();
      final createdAt = _asDate(item['createdAt']) ?? DateTime.now();
      result.add(
        Category(
          id: id,
          name: name == null || name.isEmpty ? 'Sin nombre' : name,
          colorValue: _asInt(item['color']) ?? 0xFF3B82F6,
          createdAt: createdAt,
          updatedAt: _asDate(item['updatedAt']) ?? createdAt,
        ),
      );
    }
    return result;
  }

  List<Task> _parseTasks(Object? raw, List<Category> categories) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const StorageException(
        'La copia de seguridad tiene un formato inválido en "tasks".',
      );
    }

    final categoryIds = categories.map((category) => category.id).toSet();
    final now = DateTime.now();
    final result = <Task>[];
    final seenIds = <String>{};

    for (final item in raw) {
      if (item is! Map) continue;
      final id = _asString(item['id']);
      if (id == null || !seenIds.add(id)) continue;

      final title = _asString(item['title'])?.trim();
      if (title == null || title.isEmpty) continue;

      final createdAt = _asDate(item['createdAt']) ?? now;
      final updatedAt = _asDate(item['updatedAt']) ?? createdAt;
      final status = TaskStatus.fromValue(_asInt(item['status']));
      final categoryId = _asString(item['categoryId']);

      result.add(
        Task(
          id: id,
          title: title,
          description: _asString(item['description']),
          priority: TaskPriority.fromValue(_asInt(item['priority'])),
          status: status,
          // Una categoría que no viene en la copia dejaría la tarea apuntando
          // a una clave foránea inexistente.
          categoryId: categoryId != null && categoryIds.contains(categoryId)
              ? categoryId
              : null,
          dueDate: _asDate(item['dueDate']),
          createdAt: createdAt,
          updatedAt: updatedAt,
          completedAt: status == TaskStatus.completed
              ? (_asDate(item['completedAt']) ?? updatedAt)
              : null,
          isArchived: item['isArchived'] == true,
          sortOrder: _asInt(item['sortOrder']) ?? 0,
          subtasks: _parseSubtasks(item['subtasks'], taskId: id, now: now),
        ),
      );
    }
    return result;
  }

  List<Subtask> _parseSubtasks(
    Object? raw, {
    required String taskId,
    required DateTime now,
  }) {
    if (raw is! List) return const [];

    final result = <Subtask>[];
    final seenIds = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final id = _asString(item['id']);
      final title = _asString(item['title'])?.trim();
      if (id == null || title == null || title.isEmpty) continue;
      if (!seenIds.add(id)) continue;

      final isCompleted = item['isCompleted'] == true;
      final createdAt = _asDate(item['createdAt']) ?? now;
      result.add(
        Subtask(
          id: id,
          taskId: taskId,
          title: title,
          isCompleted: isCompleted,
          createdAt: createdAt,
          completedAt: isCompleted
              ? (_asDate(item['completedAt']) ?? createdAt)
              : null,
          sortOrder: _asInt(item['sortOrder']) ?? 0,
        ),
      );
    }
    return result;
  }

  String? _asString(Object? value) => value is String ? value : null;

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _asDate(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
