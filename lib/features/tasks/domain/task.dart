import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

class Task {
  /// Tiempo durante el cual una tarea completada todavía puede editarse,
  /// desmarcarse o eliminarse. Pasado este plazo queda bloqueada.
  static const Duration completionEditWindow = Duration(hours: 4);

  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final String? categoryId;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool isArchived;
  final int sortOrder;

  // Joined/calculated optional fields for UI
  final Category? category;
  final List<Subtask> subtasks;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.pending,
    this.categoryId,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.isArchived = false,
    this.sortOrder = 0,
    this.category,
    this.subtasks = const [],
  });

  bool get isCompleted => status == TaskStatus.completed;

  /// Momento de referencia para el bloqueo de tareas completadas.
  ///
  /// [completedAt] es la fuente principal. Para datos antiguos creados antes
  /// de que se registrara la fecha de finalización se usa [updatedAt].
  DateTime get completionReference => completedAt ?? updatedAt;

  /// Indica si la tarea completada ya superó las 4 horas de gracia y, por
  /// tanto, no puede editarse ni eliminarse.
  bool get isCompletionLocked {
    if (!isCompleted) return false;
    final deadline = completionReference.add(completionEditWindow);
    return !DateTime.now().isBefore(deadline);
  }

  /// Tiempo restante para poder editar una tarea completada.
  Duration get remainingEditTime {
    if (!isCompleted) return Duration.zero;
    final deadline = completionReference.add(completionEditWindow);
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get totalSubtasks => subtasks.length;
  int get completedSubtasks => subtasks.where((s) => s.isCompleted).length;

  /// Progress percentage (0.0 to 100.0) based on subtasks
  double get progress {
    if (subtasks.isEmpty) {
      return isCompleted ? 100.0 : 0.0;
    }
    return (completedSubtasks / totalSubtasks) * 100.0;
  }

  bool get isOverdue {
    if (dueDate == null || isCompleted || isArchived) return false;
    final now = DateTime.now();
    return dueDate!.isBefore(now);
  }

  bool get isDueToday {
    if (dueDate == null || isArchived) return false;
    final now = DateTime.now();
    final d = dueDate!;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    String? categoryId,
    bool clearCategory = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isArchived,
    int? sortOrder,
    Category? category,
    bool clearCategoryObject = false,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      category: clearCategoryObject ? null : (category ?? this.category),
      subtasks: subtasks ?? this.subtasks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          priority == other.priority &&
          status == other.status &&
          categoryId == other.categoryId &&
          dueDate == other.dueDate &&
          isArchived == other.isArchived &&
          completedAt == other.completedAt &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      (description?.hashCode ?? 0) ^
      priority.hashCode ^
      status.hashCode ^
      (categoryId?.hashCode ?? 0) ^
      (dueDate?.hashCode ?? 0) ^
      isArchived.hashCode ^
      sortOrder.hashCode;
}

/// Tareas que debe mostrar el widget flotante: las completadas se ocultan.
List<Task> excludeCompletedTasks(Iterable<Task> tasks) =>
    tasks.where((task) => !task.isCompleted).toList();
