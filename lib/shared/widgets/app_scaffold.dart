import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:task_check/core/constants/app_constants.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/features/categories/presentation/category_management_dialog.dart';
import 'package:task_check/features/desktop_widget/services/widget_autostart_service.dart';
import 'package:task_check/features/desktop_widget/services/widget_launcher.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_form_dialog.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppScaffold({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _isSidebarCollapsed = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openNewTaskDialog() {
    showDialog(context: context, builder: (ctx) => const TaskFormDialog());
  }

  Future<void> _openFloatingWidget() async {
    // Remember that the widget was active and restore it on next login before
    // launching it, so the widget process already sees the preference.
    final preferences = ref.read(preferencesRepositoryProvider);
    await preferences.setWidgetAutoStartEnabled(true);
    await WidgetAutostartService.setEnabled(true);

    // Launch floating widget window as an independent desktop process
    final launched = await WidgetLauncher.launch();
    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la ventana flotante'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ventana flotante abierta'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Counts
    final pendingCount = ref.watch(pendingTasksCountProvider);
    final todayCount = ref.watch(todayTasksCountProvider);
    final importantCount = ref.watch(importantTasksCountProvider);
    final inProgressCount = ref.watch(inProgressTasksCountProvider);
    final completedCount = ref.watch(completedTasksCountProvider);
    final archivedCount = ref.watch(archivedTasksCountProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _openNewTaskDialog,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            context.go('/settings'),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              // Desktop Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: _isSidebarCollapsed ? 72 : 250,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF101622)
                      : const Color(0xFFF1F5F9),
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? const Color(0xFF222F3E)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: OverflowBox(
                  minWidth: _isSidebarCollapsed ? 72 : 250,
                  maxWidth: _isSidebarCollapsed ? 72 : 250,
                  alignment: Alignment.topLeft,
                  child: Column(
                    children: [
                      // App Logo & Toggle
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isSidebarCollapsed ? 8 : 14,
                          vertical: 14,
                        ),
                        child: _isSidebarCollapsed
                            ? Center(
                                child: Tooltip(
                                  message: 'Expandir menú lateral',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      setState(
                                        () => _isSidebarCollapsed = false,
                                      );
                                    },
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppConstants.appName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                        ),
                                        Text(
                                          'Productividad',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.hintColor,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.keyboard_double_arrow_left_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _isSidebarCollapsed = true,
                                      );
                                    },
                                    tooltip: 'Colapsar menú lateral',
                                  ),
                                ],
                              ),
                      ),

                      // New Task Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: _isSidebarCollapsed
                            ? IconButton.filled(
                                icon: const Icon(Icons.add),
                                tooltip: 'Nueva Tarea (Ctrl+N)',
                                onPressed: _openNewTaskDialog,
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text(
                                    'Nueva Tarea',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: _openNewTaskDialog,
                                ),
                              ),
                      ),

                      const SizedBox(height: 8),
                      const Divider(height: 1),

                      // Navigation Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          children: [
                            _buildNavItem(
                              icon: Icons.dashboard_outlined,
                              activeIcon: Icons.dashboard_rounded,
                              label: 'Inicio',
                              route: '/',
                            ),
                            _buildNavItem(
                              icon: Icons.auto_awesome_outlined,
                              activeIcon: Icons.auto_awesome_rounded,
                              label: 'Asistente IA',
                              route: '/ai',
                              badgeColor: const Color(0xFF8B5CF6),
                            ),
                            _buildNavItem(
                              icon: Icons.wb_sunny_outlined,
                              activeIcon: Icons.wb_sunny_rounded,
                              label: 'Mi día',
                              route: '/my-day',
                              badgeCount: todayCount,
                            ),
                            _buildNavItem(
                              icon: Icons.checklist_rounded,
                              activeIcon: Icons.checklist_rounded,
                              label: 'Todas las tareas',
                              route: '/all-tasks',
                              badgeCount: pendingCount,
                            ),
                            _buildNavItem(
                              icon: Icons.calendar_month_outlined,
                              activeIcon: Icons.calendar_month_rounded,
                              label: 'Próximas',
                              route: '/upcoming',
                            ),
                            _buildNavItem(
                              icon: Icons.star_outline_rounded,
                              activeIcon: Icons.star_rounded,
                              label: 'Importantes',
                              route: '/important',
                              badgeCount: importantCount,
                              badgeColor: Colors.amber[700],
                            ),
                            _buildNavItem(
                              icon: Icons.hourglass_top_outlined,
                              activeIcon: Icons.hourglass_top_rounded,
                              label: 'En progreso',
                              route: '/in-progress',
                              badgeCount: inProgressCount,
                              badgeColor: Colors.blue,
                            ),
                            _buildNavItem(
                              icon: Icons.task_alt_rounded,
                              activeIcon: Icons.task_alt_rounded,
                              label: 'Completadas',
                              route: '/completed',
                              badgeCount: completedCount,
                              badgeColor: Colors.green,
                            ),
                            _buildNavItem(
                              icon: Icons.archive_outlined,
                              activeIcon: Icons.archive_rounded,
                              label: 'Archivadas',
                              route: '/archived',
                              badgeCount: archivedCount,
                            ),

                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            _buildNavItem(
                              icon: Icons.category_outlined,
                              activeIcon: Icons.category_rounded,
                              label: 'Categorías',
                              route: '/categories',
                              onTapOverride: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) =>
                                      const CategoryManagementDialog(),
                                );
                              },
                            ),
                            _buildNavItem(
                              icon: Icons.bar_chart_rounded,
                              activeIcon: Icons.bar_chart_rounded,
                              label: 'Estadísticas',
                              route: '/statistics',
                            ),
                            _buildNavItem(
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings_rounded,
                              label: 'Configuración',
                              route: '/settings',
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Floating Widget Trigger Button & Footer
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _isSidebarCollapsed
                            ? IconButton(
                                icon: const Icon(
                                  Icons.picture_in_picture_alt_rounded,
                                ),
                                tooltip: 'Abrir Widget Flotante',
                                onPressed: _openFloatingWidget,
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.picture_in_picture_alt_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Widget Flotante',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: _openFloatingWidget,
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content Area
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    int? badgeCount,
    Color? badgeColor,
    VoidCallback? onTapOverride,
  }) {
    final theme = Theme.of(context);
    final isSelected = widget.currentRoute == route;

    void handleTap() {
      if (onTapOverride != null) {
        onTapOverride();
      } else {
        context.go(route);
      }
    }

    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: InkWell(
            onTap: handleTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 40,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.hintColor,
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor ?? theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          minLeadingWidth: 24,
          leading: Icon(
            isSelected ? activeIcon : icon,
            size: 20,
            color: isSelected ? theme.colorScheme.primary : theme.hintColor,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.textTheme.bodyMedium?.color,
            ),
          ),
          trailing: badgeCount != null && badgeCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        badgeColor?.withValues(alpha: 0.15) ??
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor ?? theme.colorScheme.primary,
                    ),
                  ),
                )
              : null,
          onTap: handleTap,
        ),
      ),
    );
  }
}
