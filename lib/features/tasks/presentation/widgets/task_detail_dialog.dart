import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/errors/error_handler.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/core/utils/date_formatter.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_form_dialog.dart';
import 'package:uuid/uuid.dart';

class TaskDetailDialog extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailDialog({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends ConsumerState<TaskDetailDialog> {
  final TextEditingController _newSubtaskController = TextEditingController();

  @override
  void dispose() {
    _newSubtaskController.dispose();
    super.dispose();
  }

  Future<bool> _runGuarded(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) ErrorHandler.showErrorSnackBar(context, error);
      return false;
    }
  }

  Future<void> _addSubtask(String taskId) async {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;

    final newSubtask = Subtask(
      id: const Uuid().v4(),
      taskId: taskId,
      title: title,
      createdAt: DateTime.now(),
    );

    await _runGuarded(() async {
      await ref.read(subtaskRepositoryProvider).addSubtask(newSubtask);
      if (mounted) _newSubtaskController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(allActiveTasksProvider);
    final archivedAsync = ref.watch(archivedTasksProvider);
    final theme = Theme.of(context);

    // Find task in active or archived
    final allTasks = [
      ...(taskAsync.asData?.value ?? []),
      ...(archivedAsync.asData?.value ?? []),
    ];
    final taskIndex = allTasks.indexWhere((t) => t.id == widget.taskId);

    if (taskIndex == -1) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tarea no encontrada'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    }

    final task = allTasks[taskIndex];
    final isLocked = task.isCompletionLocked;
    final subtasksStream = ref
        .watch(subtaskRepositoryProvider)
        .watchSubtasksForTask(task.id);

    return Dialog(
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                // Priority Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: task.priority.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: task.priority.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        task.priority.icon,
                        size: 14,
                        color: task.priority.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.priority.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: task.priority.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Category Tag
                if (task.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Color(task.category!.colorValue)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.category!.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Color(task.category!.colorValue),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const Spacer(),

                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: isLocked
                      ? 'Bloqueada: no editable tras 4 horas'
                      : 'Editar tarea',
                  onPressed: isLocked
                      ? null
                      : () async {
                          await showDialog(
                            context: context,
                            builder: (ctx) => TaskFormDialog(taskToEdit: task),
                          );
                        },
                ),

                // Archive / Restore
                IconButton(
                  icon: Icon(
                    task.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 20,
                  ),
                  tooltip: task.isArchived
                      ? 'Restaurar tarea'
                      : 'Archivar tarea',
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final archived = await _runGuarded(
                      () => ref
                          .read(taskRepositoryProvider)
                          .setTaskArchived(task.id, !task.isArchived),
                    );
                    if (archived) navigator.pop();
                  },
                ),

                // Close Button
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Task Title & Complete Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: task.isCompleted,
                  onChanged: isLocked
                      ? null
                      : (val) {
                          _runGuarded(
                            () => ref
                                .read(taskRepositoryProvider)
                                .setTaskStatus(
                                  task.id,
                                  val == true
                                      ? TaskStatus.completed
                                      : TaskStatus.pending,
                                ),
                          );
                        },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? theme.hintColor : null,
                    ),
                  ),
                ),
              ],
            ),

            if (isLocked) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tarea completada hace más de 4 horas: ya no puede '
                          'editarse ni eliminarse, pero sí archivarse.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  task.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Meta info (Due Date, Created, Status)
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: task.isOverdue ? Colors.red : theme.hintColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormatter.formatDueDate(task.dueDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: task.isOverdue ? Colors.red : theme.hintColor,
                          fontWeight: task.isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        task.status.icon,
                        size: 14,
                        color: task.status.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        task.status.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: task.status.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (task.completedAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Completada: ${DateFormatter.formatDateTime(task.completedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Subtasks Section
            StreamBuilder<List<Subtask>>(
              stream: subtasksStream,
              builder: (context, snapshot) {
                final subtasks = snapshot.data ?? [];
                final completedCount = subtasks
                    .where((s) => s.isCompleted)
                    .length;
                final total = subtasks.length;
                final progressPercent = total > 0
                    ? (completedCount / total) * 100
                    : 0.0;

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtasks Header with Progress
                      Row(
                        children: [
                          Text(
                            'Subtareas ($completedCount de $total)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (total > 0)
                            Text(
                              '${progressPercent.toInt()}%',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? completedCount / total : 0,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressPercent == 100
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Add Subtask input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newSubtaskController,
                              enabled: !isLocked,
                              decoration: InputDecoration(
                                hintText: isLocked
                                    ? 'Tarea bloqueada'
                                    : 'Añadir nueva subtarea...',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: isLocked
                                  ? null
                                  : (_) => _addSubtask(task.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Añadir'),
                            onPressed: isLocked
                                ? null
                                : () => _addSubtask(task.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Subtasks list
                      Expanded(
                        child: subtasks.isEmpty
                            ? Center(
                                child: Text(
                                  'Sin subtareas. Añade subtareas para dividir el trabajo.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: subtasks.length,
                                itemBuilder: (context, index) {
                                  final sub = subtasks[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: sub.isCompleted,
                                          onChanged: isLocked
                                              ? null
                                              : (val) {
                                                  _runGuarded(
                                                    () => ref
                                                        .read(
                                                          subtaskRepositoryProvider,
                                                        )
                                                        .setSubtaskCompleted(
                                                          sub.id,
                                                          val == true,
                                                        ),
                                                  );
                                                },
                                        ),
                                        Expanded(
                                          child: Text(
                                            sub.title,
                                            style: TextStyle(
                                              decoration: sub.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: sub.isCompleted
                                                  ? theme.hintColor
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                          ),
                                          color: Colors.red.withValues(
                                            alpha: 0.7,
                                          ),
                                          tooltip: isLocked
                                              ? 'Tarea bloqueada'
                                              : 'Eliminar subtarea',
                                          onPressed: isLocked
                                              ? null
                                              : () {
                                                  _runGuarded(
                                                    () => ref
                                                        .read(
                                                          subtaskRepositoryProvider,
                                                        )
                                                        .deleteSubtask(sub.id),
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
