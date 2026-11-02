import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:task_check/features/archive/presentation/archive_screen.dart';
import 'package:task_check/features/dashboard/presentation/dashboard_screen.dart';
import 'package:task_check/features/settings/presentation/settings_screen.dart';
import 'package:task_check/features/statistics/presentation/statistics_screen.dart';
import 'package:task_check/features/tasks/presentation/task_list_screen.dart';
import 'package:task_check/shared/widgets/app_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(currentRoute: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/my-day',
            builder: (context, state) => const TaskListScreen(
              mode: TaskListFilterMode.myDay,
              title: 'Mi Día',
              icon: Icons.wb_sunny_rounded,
            ),
          ),
          GoRoute(
            path: '/all-tasks',
            builder: (context, state) => const TaskListScreen(
              mode: TaskListFilterMode.all,
              title: 'Todas las Tareas',
              icon: Icons.checklist_rounded,
            ),
          ),
          GoRoute(
            path: '/upcoming',
            builder: (context, state) => const TaskListScreen(
              mode: TaskListFilterMode.upcoming,
              title: 'Próximas',
              icon: Icons.calendar_month_rounded,
            ),
          ),
          GoRoute(
            path: '/important',
            builder: (context, state) => const TaskListScreen(
              mode: TaskListFilterMode.important,
              title: 'Importantes',
              icon: Icons.star_rounded,
            ),
          ),
          GoRoute(
            path: '/in-progress',
            builder: (context, state) => const TaskListScreen(
              mode: TaskListFilterMode.inProgress,
              title: 'En Progreso',
              icon: Icons.hourglass_top_rounded,
            ),
          ),
          GoRoute(
            path: '/completed',
            builder: (context, state) => const TaskListScreen(
              mode: TaskListFilterMode.completed,
              title: 'Completadas',
              icon: Icons.task_alt_rounded,
            ),
          ),
          GoRoute(
            path: '/archived',
            builder: (context, state) => const ArchiveScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) =>
                const DashboardScreen(), // Opens dialog via sidebar
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
