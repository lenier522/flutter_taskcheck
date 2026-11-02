import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/errors/error_handler.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/core/utils/date_formatter.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:uuid/uuid.dart';

class TaskFormDialog extends ConsumerStatefulWidget {
  final Task? taskToEdit;
  final String? initialCategoryId;

  const TaskFormDialog({super.key, this.taskToEdit, this.initialCategoryId});

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _subtaskInputController;

  late TaskPriority _priority;
  late TaskStatus _status;
  String? _selectedCategoryId;
  DateTime? _dueDate;
  final List<Subtask> _tempSubtasks = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _subtaskInputController = TextEditingController();

    _priority = t?.priority ?? TaskPriority.normal;
    _status = t?.status ?? TaskStatus.pending;
    _selectedCategoryId = t?.categoryId ?? widget.initialCategoryId;
    _dueDate = t?.dueDate;

    if (t != null && t.subtasks.isNotEmpty) {
      _tempSubtasks.addAll(t.subtasks);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subtaskInputController.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final text = _subtaskInputController.text.trim();
    if (text.isEmpty) return;

    final newSubtask = Subtask(
      id: const Uuid().v4(),
      taskId: widget.taskToEdit?.id ?? '',
      title: text,
      createdAt: DateTime.now(),
      sortOrder: _tempSubtasks.length,
    );

    setState(() {
      _tempSubtasks.add(newSubtask);
      _subtaskInputController.clear();
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _dueDate != null
            ? TimeOfDay(hour: _dueDate!.hour, minute: _dueDate!.minute)
            : const TimeOfDay(hour: 12, minute: 0),
      );

      setState(() {
        if (pickedTime != null) {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        } else {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            23,
            59,
          );
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final trimmedTitle = _titleController.text.trim();
    if (trimmedTitle.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(taskRepositoryProvider);
      final now = DateTime.now();

      if (widget.taskToEdit != null) {
        final updated = widget.taskToEdit!.copyWith(
          title: trimmedTitle,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          priority: _priority,
          status: _status,
          categoryId: _selectedCategoryId,
          clearCategory: _selectedCategoryId == null,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
          updatedAt: now,
        );
        await repo.updateTask(updated);
      } else {
        final taskId = const Uuid().v4();
        final finalSubtasks = _tempSubtasks
            .map((s) => s.copyWith(taskId: taskId))
            .toList();

        final newTask = Task(
          id: taskId,
          title: trimmedTitle,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          priority: _priority,
          status: _status,
          categoryId: _selectedCategoryId,
          dueDate: _dueDate,
          createdAt: now,
          updatedAt: now,
          subtasks: finalSubtasks,
        );
        await repo.createTask(newTask);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ErrorHandler.showErrorSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final categories = categoriesAsync.asData?.value ?? [];
    final theme = Theme.of(context);
    final isEditing = widget.taskToEdit != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: Dialog(
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      isEditing
                          ? Icons.edit_note_rounded
                          : Icons.add_task_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Editar Tarea' : 'Nueva Tarea',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar (Esc)',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Título de la tarea *',
                            hintText:
                                'Ej. Diseñar arquitectura de base de datos',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El título es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                            hintText: 'Detalles adicionales o notas...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Priority & Category Row
                        Row(
                          children: [
                            // Priority Selector
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Prioridad',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<TaskPriority>(
                                    initialValue: _priority,
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    items: TaskPriority.values.map((p) {
                                      return DropdownMenuItem(
                                        value: p,
                                        child: Row(
                                          children: [
                                            Icon(
                                              p.icon,
                                              color: p.color,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(p.label),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _priority = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Category Selector
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Categoría',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String?>(
                                    initialValue: _selectedCategoryId,
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Sin categoría'),
                                      ),
                                      ...categories.map((c) {
                                        return DropdownMenuItem<String?>(
                                          value: c.id,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Color(c.colorValue),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(c.name),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedCategoryId = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Due Date Picker Row
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fecha límite',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _dueDate != null
                                        ? DateFormatter.formatDateTime(
                                            _dueDate!,
                                          )
                                        : 'Definir fecha límite',
                                  ),
                                  onPressed: _pickDueDate,
                                ),
                                if (_dueDate != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    tooltip: 'Quitar fecha',
                                    onPressed: () =>
                                        setState(() => _dueDate = null),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),

                        // Initial Subtasks for new tasks
                        if (!isEditing) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),
                          Text(
                            'Subtareas (${_tempSubtasks.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _subtaskInputController,
                                  decoration: const InputDecoration(
                                    hintText: 'Añadir subtarea...',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addSubtask(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.add_rounded),
                                onPressed: _addSubtask,
                                tooltip: 'Añadir',
                              ),
                            ],
                          ),
                          if (_tempSubtasks.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ..._tempSubtasks.asMap().entries.map((entry) {
                              final index = entry.key;
                              final sub = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(sub.title)),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => _tempSubtasks.removeAt(index),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Ctrl+Enter para guardar',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Guardar Cambios' : 'Crear Tarea'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
