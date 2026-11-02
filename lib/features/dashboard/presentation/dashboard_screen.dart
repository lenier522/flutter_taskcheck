import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_card.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_form_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(allActiveTasksProvider);

    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final formattedDate = DateFormat('EEEE, d MMMM yyyy', 'es').format(now);
    final capitalizedDate =
        formattedDate[0].toUpperCase() + formattedDate.substring(1);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (tasks) {
        final pendingTasks = tasks
            .where((t) => t.status != TaskStatus.completed)
            .toList();
        final inProgressTasks = tasks
            .where((t) => t.status == TaskStatus.inProgress)
            .toList();
        final completedTasks = tasks
            .where((t) => t.status == TaskStatus.completed)
            .toList();
        final overdueTasks = tasks.where((t) => t.isOverdue).toList();

        final importantTasks = pendingTasks
            .where(
              (t) =>
                  t.priority == TaskPriority.high ||
                  t.priority == TaskPriority.urgent,
            )
            .toList();

        final dueSoonTasks =
            pendingTasks
                .where((t) => t.dueDate != null && !t.isOverdue)
                .toList()
              ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Greeting & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, bienvenido',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          capitalizedDate,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Crear Tarea'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const TaskFormDialog(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stat Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 48) / 4;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatCard(
                          title: 'Pendientes',
                          count: pendingTasks.length,
                          icon: Icons.checklist_rounded,
                          color: Colors.blue,
                          width: itemWidth > 180
                              ? itemWidth
                              : constraints.maxWidth / 2 - 8,
                          onTap: () => context.go('/all-tasks'),
                        ),
                        _buildStatCard(
                          title: 'En progreso',
                          count: inProgressTasks.length,
                          icon: Icons.hourglass_top_rounded,
                          color: Colors.indigo,
                          width: itemWidth > 180
                              ? itemWidth
                              : constraints.maxWidth / 2 - 8,
                          onTap: () => context.go('/in-progress'),
                        ),
                        _buildStatCard(
                          title: 'Completadas',
                          count: completedTasks.length,
                          icon: Icons.check_circle_rounded,
                          color: Colors.green,
                          width: itemWidth > 180
                              ? itemWidth
                              : constraints.maxWidth / 2 - 8,
                          onTap: () => context.go('/completed'),
                        ),
                        _buildStatCard(
                          title: 'Vencidas',
                          count: overdueTasks.length,
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red,
                          width: itemWidth > 180
                              ? itemWidth
                              : constraints.maxWidth / 2 - 8,
                          onTap: () => context.go('/all-tasks'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Sections: Important / Urgent & Due Soon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Important Tasks Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 20,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tareas Importantes y Urgentes (${importantTasks.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (importantTasks.isEmpty)
                            _buildEmptyCard(
                              'No tienes tareas urgentes o importantes pendientes.',
                            )
                          else
                            ...importantTasks
                                .take(5)
                                .map((t) => TaskCard(task: t)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Due Soon Tasks Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 20,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Próximas a Vencer (${dueSoonTasks.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (dueSoonTasks.isEmpty)
                            _buildEmptyCard(
                              'No hay tareas próximas con fecha límite.',
                            )
                          else
                            ...dueSoonTasks
                                .take(5)
                                .map((t) => TaskCard(task: t)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }
}
