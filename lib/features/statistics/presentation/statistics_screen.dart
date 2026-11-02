import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeTasksAsync = ref.watch(allActiveTasksProvider);
    final archivedTasksAsync = ref.watch(archivedTasksProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    final activeTasks = activeTasksAsync.asData?.value ?? [];
    final archivedTasks = archivedTasksAsync.asData?.value ?? [];
    final categories = categoriesAsync.asData?.value ?? [];

    final totalCreated = activeTasks.length + archivedTasks.length;
    final pendingCount = activeTasks
        .where((t) => t.status == TaskStatus.pending)
        .length;
    final inProgressCount = activeTasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;
    final completedCount = activeTasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final archivedCount = archivedTasks.length;
    final overdueCount = activeTasks.where((t) => t.isOverdue).length;

    final completionRate = totalCreated > 0
        ? ((completedCount /
                      (totalCreated - archivedCount > 0
                          ? (totalCreated - archivedCount)
                          : 1)) *
                  100)
              .clamp(0.0, 100.0)
        : 0.0;

    // Distribution by Priority (active tasks)
    final lowCount = activeTasks
        .where((t) => t.priority == TaskPriority.low)
        .length;
    final normalCount = activeTasks
        .where((t) => t.priority == TaskPriority.normal)
        .length;
    final highCount = activeTasks
        .where((t) => t.priority == TaskPriority.high)
        .length;
    final urgentCount = activeTasks
        .where((t) => t.priority == TaskPriority.urgent)
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Estadísticas y Métricas',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 48) / 4;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildKpiCard(
                      'Total Creadas',
                      '$totalCreated',
                      Icons.format_list_bulleted_rounded,
                      Colors.blue,
                      cardWidth,
                    ),
                    _buildKpiCard(
                      'Pendientes',
                      '$pendingCount',
                      Icons.radio_button_unchecked,
                      const Color(0xFF64748B),
                      cardWidth,
                    ),
                    _buildKpiCard(
                      'En progreso',
                      '$inProgressCount',
                      Icons.hourglass_top_rounded,
                      Colors.indigo,
                      cardWidth,
                    ),
                    _buildKpiCard(
                      'Completadas',
                      '$completedCount',
                      Icons.check_circle_rounded,
                      Colors.green,
                      cardWidth,
                    ),
                    _buildKpiCard(
                      'Vencidas',
                      '$overdueCount',
                      Icons.warning_amber_rounded,
                      Colors.red,
                      cardWidth,
                    ),
                    _buildKpiCard(
                      'Archivadas',
                      '$archivedCount',
                      Icons.archive_outlined,
                      Colors.brown,
                      cardWidth,
                    ),
                    _buildKpiCard(
                      'Tasa de Finalización',
                      '${completionRate.toStringAsFixed(1)}%',
                      Icons.trending_up_rounded,
                      Colors.teal,
                      cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Charts Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority Distribution Chart
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distribución por Prioridad',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (activeTasks.isEmpty)
                            const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'Sin datos para mostrar',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 200,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY:
                                      ([
                                                lowCount,
                                                normalCount,
                                                highCount,
                                                urgentCount,
                                              ].reduce(
                                                (a, b) => a > b ? a : b,
                                              ) +
                                              2)
                                          .toDouble(),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (val, meta) {
                                          switch (val.toInt()) {
                                            case 0:
                                              return const Text(
                                                'Baja',
                                                style: TextStyle(fontSize: 11),
                                              );
                                            case 1:
                                              return const Text(
                                                'Normal',
                                                style: TextStyle(fontSize: 11),
                                              );
                                            case 2:
                                              return const Text(
                                                'Alta',
                                                style: TextStyle(fontSize: 11),
                                              );
                                            case 3:
                                              return const Text(
                                                'Urgente',
                                                style: TextStyle(fontSize: 11),
                                              );
                                          }
                                          return const SizedBox();
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 28,
                                        getTitlesWidget: (val, meta) => Text(
                                          '${val.toInt()}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: [
                                    BarChartGroupData(
                                      x: 0,
                                      barRods: [
                                        BarChartRodData(
                                          toY: lowCount.toDouble(),
                                          color: TaskPriority.low.color,
                                          width: 22,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    BarChartGroupData(
                                      x: 1,
                                      barRods: [
                                        BarChartRodData(
                                          toY: normalCount.toDouble(),
                                          color: TaskPriority.normal.color,
                                          width: 22,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    BarChartGroupData(
                                      x: 2,
                                      barRods: [
                                        BarChartRodData(
                                          toY: highCount.toDouble(),
                                          color: TaskPriority.high.color,
                                          width: 22,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    BarChartGroupData(
                                      x: 3,
                                      barRods: [
                                        BarChartRodData(
                                          toY: urgentCount.toDouble(),
                                          color: TaskPriority.urgent.color,
                                          width: 22,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Category Distribution Chart
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distribución por Categoría',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (activeTasks.isEmpty || categories.isEmpty)
                            const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'Sin datos para mostrar',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            _buildCategoryBreakdown(categories, activeTasks),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(
    List<dynamic> categories,
    List<dynamic> tasks,
  ) {
    return Column(
      children: categories.map((cat) {
        final count = tasks.where((t) => t.categoryId == cat.id).length;
        final total = tasks.length;
        final pct = total > 0 ? (count / total) : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(cat.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$count tareas (${(pct * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Color(cat.colorValue)
                      .withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(cat.colorValue),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width > 180 ? width : 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
