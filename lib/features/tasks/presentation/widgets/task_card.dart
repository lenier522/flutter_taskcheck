import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/core/errors/error_handler.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/core/utils/date_formatter.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_detail_dialog.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_form_dialog.dart';

class TaskCard extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  bool _subtasksExpanded = false;

  Future<void> _runGuarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) ErrorHandler.showErrorSnackBar(context, error);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (widget.task.isCompletionLocked) {
      ErrorHandler.showErrorSnackBar(context, const TaskLockedException());
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          '¿Seguro que deseas eliminar definitivamente la tarea "${widget.task.title}" y sus subtareas?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _runGuarded(
        () => ref.read(taskRepositoryProvider).deleteTask(widget.task.id),
      );
    }
  }

  void _toggleSubtask(Subtask subtask) {
    if (widget.task.isCompletionLocked) {
      ErrorHandler.showErrorSnackBar(context, const TaskLockedException());
      return;
    }
    _runGuarded(
      () => ref
          .read(subtaskRepositoryProvider)
          .setSubtaskCompleted(subtask.id, !subtask.isCompleted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final hasSubtasks = task.subtasks.isNotEmpty;
    final isLocked = task.isCompletionLocked;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            widget.onTap ??
            () {
              showDialog(
                context: context,
                builder: (ctx) => TaskDetailDialog(taskId: task.id),
              );
            },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Complete Checkbox
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Tooltip(
                      message: isLocked
                          ? 'Tarea bloqueada: ya no puede editarse'
                          : task.isCompleted
                          ? 'Marcar como pendiente'
                          : 'Marcar como completada',
                      child: Checkbox(
                        value: task.isCompleted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
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
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Title and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted ? theme.hintColor : null,
                          ),
                        ),
                        if (task.description != null &&
                            task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Badges Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Priority Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: task.priority.color.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    task.priority.icon,
                                    size: 12,
                                    color: task.priority.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.priority.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: task.priority.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Lock Badge (completed more than 4 hours ago)
                            if (isLocked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_clock_rounded,
                                      size: 12,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Bloqueada',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Status Badge (if in progress)
                            if (task.status == TaskStatus.inProgress)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: task.status.color.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.status.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: task.status.color,
                                  ),
                                ),
                              ),

                            // Category Tag
                            if (task.category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(task.category!.colorValue)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.category!.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(task.category!.colorValue),
                                  ),
                                ),
                              ),

                            // Due Date Badge
                            if (task.dueDate != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: task.isOverdue
                                        ? Colors.red
                                        : theme.hintColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormatter.formatDueDate(task.dueDate),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: task.isOverdue
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: task.isOverdue
                                          ? Colors.red
                                          : theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    tooltip: 'Opciones',
                    onSelected: (action) async {
                      // Archiving stays available for locked tasks.
                      if (isLocked &&
                          action != 'detail' &&
                          action != 'archive') {
                        ErrorHandler.showErrorSnackBar(
                          context,
                          const TaskLockedException(),
                        );
                        return;
                      }

                      switch (action) {
                        case 'detail':
                          showDialog(
                            context: context,
                            builder: (ctx) => TaskDetailDialog(taskId: task.id),
                          );
                          break;
                        case 'edit':
                          showDialog(
                            context: context,
                            builder: (ctx) => TaskFormDialog(taskToEdit: task),
                          );
                          break;
                        case 'in_progress':
                          _runGuarded(
                            () => ref
                                .read(taskRepositoryProvider)
                                .setTaskStatus(task.id, TaskStatus.inProgress),
                          );
                          break;
                        case 'pending':
                          _runGuarded(
                            () => ref
                                .read(taskRepositoryProvider)
                                .setTaskStatus(task.id, TaskStatus.pending),
                          );
                          break;
                        case 'complete':
                          _runGuarded(
                            () => ref
                                .read(taskRepositoryProvider)
                                .setTaskStatus(task.id, TaskStatus.completed),
                          );
                          break;
                        case 'archive':
                          _runGuarded(
                            () => ref
                                .read(taskRepositoryProvider)
                                .setTaskArchived(task.id, !task.isArchived),
                          );
                          break;
                        case 'delete':
                          _confirmDelete(context);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'detail',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Ver detalle y subtareas'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      if (task.status != TaskStatus.inProgress)
                        const PopupMenuItem(
                          value: 'in_progress',
                          child: Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 18,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 8),
                              Text('Marcar en progreso'),
                            ],
                          ),
                        ),
                      if (task.status != TaskStatus.pending)
                        const PopupMenuItem(
                          value: 'pending',
                          child: Row(
                            children: [
                              Icon(Icons.radio_button_unchecked, size: 18),
                              SizedBox(width: 8),
                              Text('Marcar pendiente'),
                            ],
                          ),
                        ),
                      if (!task.isCompleted)
                        const PopupMenuItem(
                          value: 'complete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text('Marcar completada'),
                            ],
                          ),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(
                              task.isArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(task.isArchived ? 'Restaurar' : 'Archivar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Subtasks Section ──────────────────────────────────────────
              if (hasSubtasks) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 48, right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress row + expand toggle
                      InkWell(
                        onTap: () => setState(
                          () => _subtasksExpanded = !_subtasksExpanded,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.checklist_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${task.completedSubtasks} de ${task.totalSubtasks} subtareas',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${task.progress.toInt()}%',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: task.progress == 100
                                          ? Colors.green
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: _subtasksExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: task.totalSubtasks > 0
                              ? task.completedSubtasks / task.totalSubtasks
                              : 0,
                          minHeight: 4,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            task.progress == 100
                                ? Colors.green
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),

                      // Expandable subtask list
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: _subtasksExpanded
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  ...task.subtasks.map(
                                    (subtask) => _SubtaskRow(
                                      subtask: subtask,
                                      onToggle: () => _toggleSubtask(subtask),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline subtask row widget
// ─────────────────────────────────────────────────────────────────────────────
class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({required this.subtask, required this.onToggle});

  final Subtask subtask;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = subtask.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isDone
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDone
                        ? Colors.green
                        : theme.colorScheme.outline.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: Colors.green,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtask.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? theme.hintColor : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
