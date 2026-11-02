import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';

/// Tipos de aviso que puede generar una tarea.
enum TaskNotificationKind {
  dueSoon('due_soon'),
  overdue('overdue'),
  priority('priority');

  const TaskNotificationKind(this.key);

  final String key;
}

/// Aviso listo para mostrarse en el sistema operativo.
class TaskNotification {
  const TaskNotification({
    required this.task,
    required this.kind,
    required this.title,
    required this.body,
  });

  final Task task;
  final TaskNotificationKind kind;
  final String title;
  final String body;

  /// Clave estable para no repetir el mismo aviso: tipo + tarea.
  String get dedupeKey => '${kind.key}:${task.id}';

  /// Identificador estable para el sistema de notificaciones. Al reutilizarlo,
  /// un aviso nuevo reemplaza al anterior en lugar de duplicarlo.
  int get notificationId => dedupeKey.hashCode & 0x7fffffff;

  /// Tiempo mínimo antes de volver a avisar de lo mismo.
  Duration get repeatAfter => switch (kind) {
    TaskNotificationKind.dueSoon => const Duration(hours: 12),
    TaskNotificationKind.overdue => const Duration(hours: 12),
    TaskNotificationKind.priority => const Duration(hours: 24),
  };
}

/// Umbrales usados para decidir cuándo avisar.
class TaskNotificationWindows {
  /// Se avisa cuando la tarea vence dentro de este plazo.
  static const Duration dueSoon = Duration(hours: 24);

  /// Una tarea de prioridad alta/urgente avisa tras estar pendiente este tiempo.
  static const Duration priorityIdle = Duration(hours: 8);
}

/// Calcula los avisos que corresponden al estado actual de las tareas.
///
/// Función pura (sin acceso a disco ni a plugins) para poder probarla
/// directamente. Las tareas completadas o archivadas nunca generan avisos.
List<TaskNotification> buildTaskNotifications(
  Iterable<Task> tasks, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final result = <TaskNotification>[];

  for (final task in tasks) {
    if (task.isCompleted || task.isArchived) continue;

    final dueDate = task.dueDate;
    if (dueDate != null) {
      final remaining = dueDate.difference(reference);
      if (remaining.isNegative) {
        result.add(
          TaskNotification(
            task: task,
            kind: TaskNotificationKind.overdue,
            title: 'Tarea vencida',
            body: '"${task.title}" venció ${_describeDelay(remaining.abs())}.',
          ),
        );
      } else if (remaining <= TaskNotificationWindows.dueSoon) {
        result.add(
          TaskNotification(
            task: task,
            kind: TaskNotificationKind.dueSoon,
            title: 'Tarea al vencer',
            body: '"${task.title}" vence ${_describeRemaining(remaining)}.',
          ),
        );
      }
    }

    final isImportant =
        task.priority == TaskPriority.high ||
        task.priority == TaskPriority.urgent;
    final idle = reference.difference(task.createdAt);
    if (isImportant && idle >= TaskNotificationWindows.priorityIdle) {
      result.add(
        TaskNotification(
          task: task,
          kind: TaskNotificationKind.priority,
          title: task.priority == TaskPriority.urgent
              ? 'Tarea urgente pendiente'
              : 'Tarea importante pendiente',
          body:
              'Termina "${task.title}", lleva pendiente '
              '${_describeDelay(idle)}.',
        ),
      );
    }
  }

  return result;
}

String _describeRemaining(Duration remaining) {
  if (remaining.inMinutes < 60) {
    final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;
    return 'en $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
  }
  if (remaining.inHours < 24) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (minutes == 0) {
      return 'en $hours ${hours == 1 ? 'hora' : 'horas'}';
    }
    return 'en $hours h $minutes min';
  }
  final days = remaining.inDays;
  return 'en $days ${days == 1 ? 'día' : 'días'}';
}

String _describeDelay(Duration elapsed) {
  if (elapsed.inMinutes < 60) {
    final minutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;
    return 'hace $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
  }
  if (elapsed.inHours < 24) {
    final hours = elapsed.inHours;
    return 'hace $hours ${hours == 1 ? 'hora' : 'horas'}';
  }
  final days = elapsed.inDays;
  return 'hace $days ${days == 1 ? 'día' : 'días'}';
}
