import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_card.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_form_dialog.dart';

enum TaskListFilterMode {
  all,
  myDay,
  upcoming,
  important,
  inProgress,
  completed,
  archived,
}

enum TaskSortOption {
  createdDesc('Más recientes'),
  createdAsc('Más antiguas'),
  dueDateAsc('Fecha de vencimiento'),
  priorityDesc('Mayor prioridad'),
  titleAsc('Alfabético');

  final String label;
  const TaskSortOption(this.label);
}

class TaskListScreen extends ConsumerStatefulWidget {
  final TaskListFilterMode mode;
  final String title;
  final IconData icon;

  const TaskListScreen({
    super.key,
    required this.mode,
    required this.title,
    required this.icon,
  });

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();
  TaskSortOption _sortOption = TaskSortOption.createdDesc;
  TaskPriority? _filterPriority;
  String? _filterCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _applyFiltersAndSort(List<Task> rawTasks) {
    var list = rawTasks.where((t) {
      // Base view filter
      switch (widget.mode) {
        case TaskListFilterMode.all:
          if (t.isArchived) return false;
          break;
        case TaskListFilterMode.myDay:
          if (t.isArchived || !t.isDueToday) return false;
          break;
        case TaskListFilterMode.upcoming:
          if (t.isArchived || t.dueDate == null || t.isCompleted) return false;
          final now = DateTime.now();
          if (t.dueDate!.isBefore(now)) return false;
          break;
        case TaskListFilterMode.important:
          if (t.isArchived) return false;
          if (t.priority != TaskPriority.high &&
              t.priority != TaskPriority.urgent) {
            return false;
          }
          break;
        case TaskListFilterMode.inProgress:
          if (t.isArchived || t.status != TaskStatus.inProgress) return false;
          break;
        case TaskListFilterMode.completed:
          if (t.isArchived || !t.isCompleted) return false;
          break;
        case TaskListFilterMode.archived:
          if (!t.isArchived) return false;
          break;
      }

      // Search query
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchTitle = t.title.toLowerCase().contains(query);
        final matchDesc = t.description?.toLowerCase().contains(query) ?? false;
        if (!matchTitle && !matchDesc) return false;
      }

      // Priority filter
      if (_filterPriority != null && t.priority != _filterPriority) {
        return false;
      }

      // Category filter
      if (_filterCategoryId != null && t.categoryId != _filterCategoryId) {
        return false;
      }

      return true;
    }).toList();

    // Sort
    list.sort((a, b) {
      switch (_sortOption) {
        case TaskSortOption.createdDesc:
          return b.createdAt.compareTo(a.createdAt);
        case TaskSortOption.createdAsc:
          return a.createdAt.compareTo(b.createdAt);
        case TaskSortOption.dueDateAsc:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        case TaskSortOption.priorityDesc:
          return b.priority.value.compareTo(a.priority.value);
        case TaskSortOption.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArchivedMode = widget.mode == TaskListFilterMode.archived;
    final tasksAsync = isArchivedMode
        ? ref.watch(archivedTasksProvider)
        : ref.watch(allActiveTasksProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final categories = categoriesAsync.asData?.value ?? [];

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          'Error al cargar las tareas: $err',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (tasks) {
        final filteredTasks = _applyFiltersAndSort(tasks);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with View Title and Action
                Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filteredTasks.length}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isArchivedMode)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva Tarea'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const TaskFormDialog(),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Search & Filter Toolbar
                Row(
                  children: [
                    // Search bar
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar por título o descripción...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Priority Filter
                    DropdownButton<TaskPriority?>(
                      value: _filterPriority,
                      hint: const Text(
                        'Prioridad',
                        style: TextStyle(fontSize: 13),
                      ),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas las prioridades'),
                        ),
                        ...TaskPriority.values.map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                Icon(p.icon, color: p.color, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  p.label,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _filterPriority = val),
                    ),
                    const SizedBox(width: 12),

                    // Category Filter
                    DropdownButton<String?>(
                      value: _filterCategoryId,
                      hint: const Text(
                        'Categoría',
                        style: TextStyle(fontSize: 13),
                      ),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas las categorías'),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(c.colorValue),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  c.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _filterCategoryId = val),
                    ),
                    const SizedBox(width: 12),

                    // Sort Option
                    DropdownButton<TaskSortOption>(
                      value: _sortOption,
                      underline: const SizedBox(),
                      items: TaskSortOption.values
                          .map(
                            (opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(
                                opt.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _sortOption = val);
                      },
                    ),

                    if (_filterPriority != null ||
                        _filterCategoryId != null ||
                        _searchController.text.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Limpiar',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _filterPriority = null;
                            _filterCategoryId = null;
                            _searchController.clear();
                          });
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Tasks List or Empty State
                Expanded(
                  child: filteredTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: theme.hintColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontraron tareas',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Prueba con otros términos de búsqueda o limpia los filtros.'
                                    : 'Crea una nueva tarea para comenzar a organizar tu día.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return TaskCard(task: task);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
