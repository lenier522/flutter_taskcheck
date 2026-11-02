import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/core/services/task_notifications.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

void main() {
  final now = DateTime(2026, 3, 10, 12);

  Task buildTask({
    String id = 'task-1',
    String title = 'Enviar informe',
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.normal,
    TaskStatus status = TaskStatus.pending,
    DateTime? createdAt,
    bool isArchived = false,
  }) {
    final created = createdAt ?? now.subtract(const Duration(hours: 1));
    return Task(
      id: id,
      title: title,
      priority: priority,
      status: status,
      dueDate: dueDate,
      createdAt: created,
      updatedAt: created,
      isArchived: isArchived,
    );
  }

  test('avisa cuando la tarea vence dentro de 24 horas', () {
    final notifications = buildTaskNotifications([
      buildTask(dueDate: now.add(const Duration(hours: 3))),
    ], now: now);

    expect(notifications, hasLength(1));
    expect(notifications.single.kind, TaskNotificationKind.dueSoon);
    expect(notifications.single.title, 'Tarea al vencer');
    expect(notifications.single.body, contains('Enviar informe'));
  });

  test('no avisa si la tarea vence en más de 24 horas', () {
    final notifications = buildTaskNotifications([
      buildTask(dueDate: now.add(const Duration(days: 3))),
    ], now: now);

    expect(notifications, isEmpty);
  });

  test('avisa cuando la tarea ya venció', () {
    final notifications = buildTaskNotifications([
      buildTask(dueDate: now.subtract(const Duration(hours: 5))),
    ], now: now);

    expect(notifications, hasLength(1));
    expect(notifications.single.kind, TaskNotificationKind.overdue);
    expect(notifications.single.title, 'Tarea vencida');
  });

  test('las tareas completadas o archivadas no generan avisos', () {
    final notifications = buildTaskNotifications([
      buildTask(
        id: 'a',
        dueDate: now.subtract(const Duration(hours: 5)),
        status: TaskStatus.completed,
      ),
      buildTask(
        id: 'b',
        dueDate: now.add(const Duration(hours: 2)),
        isArchived: true,
      ),
    ], now: now);

    expect(notifications, isEmpty);
  });

  test('recuerda terminar una tarea urgente que lleva horas pendiente', () {
    final notifications = buildTaskNotifications([
      buildTask(
        priority: TaskPriority.urgent,
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
    ], now: now);

    expect(notifications, hasLength(1));
    expect(notifications.single.kind, TaskNotificationKind.priority);
    expect(notifications.single.title, 'Tarea urgente pendiente');
    expect(notifications.single.body, contains('lleva pendiente'));
  });

  test('no recuerda tareas de prioridad normal', () {
    final notifications = buildTaskNotifications([
      buildTask(createdAt: now.subtract(const Duration(days: 2))),
    ], now: now);

    expect(notifications, isEmpty);
  });

  test('no repite el recordatorio de prioridad recién creado', () {
    final notifications = buildTaskNotifications([
      buildTask(
        priority: TaskPriority.high,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ], now: now);

    expect(notifications, isEmpty);
  });

  test('la clave de deduplicación distingue tipo y tarea', () {
    final task = buildTask(
      dueDate: now.subtract(const Duration(hours: 1)),
      priority: TaskPriority.high,
      createdAt: now.subtract(const Duration(days: 1)),
    );

    final notifications = buildTaskNotifications([task], now: now);
    expect(notifications, hasLength(2));
    expect(notifications.map((n) => n.dedupeKey).toSet(), hasLength(2));
    for (final notification in notifications) {
      expect(notification.notificationId, isNonNegative);
    }
    expect(
      notifications
          .firstWhere((n) => n.kind == TaskNotificationKind.overdue)
          .repeatAfter,
      const Duration(hours: 12),
    );
  });
}
