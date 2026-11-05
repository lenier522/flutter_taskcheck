import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:task_check/core/constants/app_constants.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/core/theme/app_colors.dart';
import 'package:task_check/core/utils/date_formatter.dart';
import 'package:task_check/features/desktop_widget/services/widget_autostart_service.dart';
import 'package:task_check/features/desktop_widget/services/widget_instance_lock.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

class _DraggableScrollBehavior extends MaterialScrollBehavior {
  const _DraggableScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

enum _SortMode {
  priorityDesc('Prioridad: Alta a Baja', Icons.sort_rounded),
  priorityAsc('Prioridad: Baja a Alta', Icons.swap_vert_rounded),
  dueDate('Fecha de vencimiento', Icons.calendar_today_rounded),
  manual('Orden manual (arrastrar)', Icons.drag_indicator_rounded);

  final String label;
  final IconData icon;
  const _SortMode(this.label, this.icon);
}

// =============================================================================
// Root widget
// =============================================================================
class DesktopWidgetWindow extends ConsumerStatefulWidget {
  const DesktopWidgetWindow({super.key, required this.instanceLock});

  final WidgetInstanceLock instanceLock;

  @override
  ConsumerState<DesktopWidgetWindow> createState() =>
      _DesktopWidgetWindowState();
}

class _DesktopWidgetWindowState extends ConsumerState<DesktopWidgetWindow>
    with WindowListener, WidgetsBindingObserver {
  bool _isAlwaysOnTop = true;
  bool _collapsed = false;
  double _expandedHeight = 480.0;

  // Real-time multi-process sync timer
  Timer? _syncTimer;

  // Persist bounds after moves/resizes and as a safety net for abrupt exits.
  Timer? _boundsSaveTimer;
  Timer? _boundsWatchdogTimer;
  Rect? _lastSavedBounds;
  bool _closingFromButton = false;
  bool _isClosing = false;

  // Selected priority filter (null = all)
  TaskPriority? _selectedPriority;

  // Current sort mode
  _SortMode _sortMode = _SortMode.priorityDesc;

  // Custom manual order override
  List<String> _manualOrderIds = [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);

    final savedSize = ref.read(preferencesRepositoryProvider).getWidgetSize();
    if (savedSize != null && savedSize.height.isFinite) {
      _expandedHeight = savedSize.height;
    }

    _initAlwaysOnTop();
    _initPreventClose();

    // Auto-sync polling every 1 second: Ensures tasks created, modified or deleted
    // in the main app process automatically appear in the widget without needing a restart!
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        ref.read(appDatabaseProvider).syncFromDisk();
      }
    });

    // Extra safety: persist bounds periodically even if the window manager
    // did not emit a move/resize event before the computer was powered off.
    _boundsWatchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveWindowBounds();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _boundsSaveTimer?.cancel();
    _boundsWatchdogTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _saveWindowBounds();
    }
  }

  Future<void> _initAlwaysOnTop() async {
    try {
      await windowManager.setAlwaysOnTop(true);
      setState(() => _isAlwaysOnTop = true);
    } catch (_) {
      setState(() => _isAlwaysOnTop = false);
    }
  }

  Future<void> _initPreventClose() async {
    try {
      await windowManager.setPreventClose(true);
    } catch (error) {
      debugPrint('No se pudo interceptar el cierre del widget: $error');
    }
  }

  // ── Arrastre de la ventana ────────────────────────────────────────────────
  // Con el ratón se usa el arrastre nativo del gestor de ventanas: es suave,
  // no va con retraso y respeta los bordes del escritorio. Ese mecanismo
  // (_NET_WM_MOVERESIZE) solo reacciona a un botón del ratón pulsado, así que
  // en una pantalla táctil no mueve la ventana: para el dedo y el lápiz
  // movemos la ventana nosotros con el desplazamiento del puntero.
  Offset? _dragOrigin;
  Offset _dragOffset = Offset.zero;
  bool _manualDragActive = false;

  void _startHeaderDrag(PointerDeviceKind? kind) {
    final isFingerDrag =
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;

    if (!isFingerDrag) {
      _manualDragActive = false;
      unawaited(windowManager.startDragging());
      return;
    }

    _manualDragActive = true;
    unawaited(_beginWindowDrag());
  }

  void _updateHeaderDrag(Offset delta) {
    if (!_manualDragActive) return;
    _dragOffset += delta;
    _applyWindowDrag();
  }

  void _endHeaderDrag() {
    if (!_manualDragActive) return;
    _manualDragActive = false;
    _dragOrigin = null;
    _dragOffset = Offset.zero;
    _scheduleBoundsSave();
  }

  Future<void> _beginWindowDrag() async {
    _dragOffset = Offset.zero;
    try {
      _dragOrigin = await windowManager.getPosition();
      _applyWindowDrag();
    } catch (error) {
      debugPrint('No se pudo iniciar el arrastre táctil del widget: $error');
      _dragOrigin = null;
    }
  }

  void _applyWindowDrag() {
    final origin = _dragOrigin;
    if (origin == null) return;
    unawaited(windowManager.setPosition(origin + _dragOffset));
  }

  Future<void> _toggleAlwaysOnTop() async {
    final next = !_isAlwaysOnTop;
    try {
      await windowManager.setAlwaysOnTop(next);
      setState(() => _isAlwaysOnTop = next);
    } catch (_) {}
  }

  Future<void> _toggleCollapse() async {
    final next = !_collapsed;
    try {
      final bounds = await windowManager.getBounds();
      if (next) {
        _expandedHeight = bounds.height;
        setState(() => _collapsed = true);
        await windowManager.setSize(Size(bounds.width, 50));
      } else {
        setState(() => _collapsed = false);
        await windowManager.setSize(Size(bounds.width, _expandedHeight));
      }
      _scheduleBoundsSave();
    } catch (error) {
      debugPrint('No se pudo contraer/expandir el widget: $error');
    }
  }

  @override
  void onWindowMoved() => _scheduleBoundsSave();

  @override
  void onWindowResized() => _scheduleBoundsSave();

  @override
  void onWindowClose() {
    _handleWindowClose();
  }

  void _scheduleBoundsSave() {
    _boundsSaveTimer?.cancel();
    _boundsSaveTimer = Timer(
      const Duration(milliseconds: 250),
      _saveWindowBounds,
    );
  }

  Future<void> _saveWindowBounds([bool force = false]) async {
    if (!mounted || (!force && _isClosing)) return;
    try {
      final bounds = await windowManager.getBounds();
      final size = Size(
        bounds.width,
        _collapsed ? _expandedHeight : bounds.height,
      );
      final rect = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        size.width,
        size.height,
      );
      if (_lastSavedBounds == rect) return;
      _lastSavedBounds = rect;

      final preferences = ref.read(preferencesRepositoryProvider);
      await preferences.saveWidgetPosition(bounds.topLeft);
      await preferences.saveWidgetSize(size);
    } catch (error) {
      debugPrint('No se pudieron guardar los límites del widget: $error');
    }
  }

  Future<void> _handleWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;

    _boundsSaveTimer?.cancel();
    _boundsWatchdogTimer?.cancel();
    await _saveWindowBounds(true);

    if (_closingFromButton) {
      final preferences = ref.read(preferencesRepositoryProvider);
      await preferences.setWidgetAutoStartEnabled(false);
      await WidgetAutostartService.setEnabled(false);
    }

    await widget.instanceLock.release();
    await windowManager.destroy();
  }

  Future<void> _closeWidget() async {
    _closingFromButton = true;
    await _handleWindowClose();
  }

  Future<void> _openMainApp() async {
    try {
      final executable = Platform.resolvedExecutable;
      await Process.start(executable, [], mode: ProcessStartMode.detached);
    } catch (_) {}
  }

  List<Task> _sortAndFilterTasks(List<Task> allTasks) {
    // Completed tasks are never shown in the floating widget.
    var list = excludeCompletedTasks(allTasks);

    // 1. Filter by priority if selected
    if (_selectedPriority != null) {
      list = list
          .where((task) => task.priority == _selectedPriority)
          .toList(growable: true);
    }

    // 2. Sort according to _sortMode
    switch (_sortMode) {
      case _SortMode.priorityDesc:
        list.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          final p = b.priority.value.compareTo(a.priority.value);
          if (p != 0) return p;
          if (a.dueDate != null && b.dueDate != null) {
            return a.dueDate!.compareTo(b.dueDate!);
          } else if (a.dueDate != null) {
            return -1;
          } else if (b.dueDate != null) {
            return 1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
        break;

      case _SortMode.priorityAsc:
        list.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          final p = a.priority.value.compareTo(b.priority.value);
          if (p != 0) return p;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;

      case _SortMode.dueDate:
        list.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          if (a.dueDate == null && b.dueDate == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;

      case _SortMode.manual:
        if (_manualOrderIds.isNotEmpty) {
          list.sort((a, b) {
            final idxA = _manualOrderIds.indexOf(a.id);
            final idxB = _manualOrderIds.indexOf(b.id);
            if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
            if (idxA != -1) return -1;
            if (idxB != -1) return 1;
            return 0;
          });
        }
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tasksAsync = ref.watch(allActiveTasksProvider);

    final allTasks = excludeCompletedTasks(
      tasksAsync.asData?.value ?? const <Task>[],
    );
    final visibleTasks = _sortAndFilterTasks(allTasks);

    final pendingCount = allTasks.length;

    // Semi-transparent frosted glass using the app's real theme colors
    final bgColor = isDark
        ? const Color(0xE8151C28) // Deep translucent navy
        : const Color(0xF4FFFFFF); // Clean translucent white
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.lightBorder.withValues(alpha: 0.9);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Header Bar ─────────────────────────────────────────────
                _WidgetHeader(
                  pendingCount: pendingCount,
                  sortMode: _sortMode,
                  isAlwaysOnTop: _isAlwaysOnTop,
                  collapsed: _collapsed,
                  onSelectSortMode: (mode) => setState(() => _sortMode = mode),
                  onTogglePin: _toggleAlwaysOnTop,
                  onToggleCollapse: _toggleCollapse,
                  onOpenApp: _openMainApp,
                  onClose: _closeWidget,
                  onDragStart: _startHeaderDrag,
                  onDragUpdate: _updateHeaderDrag,
                  onDragEnd: _endHeaderDrag,
                ),

                if (!_collapsed) ...[
                  // ── Priority Filter Pills ────────────────────────────────
                  _PriorityFilterPills(
                    allTasks: allTasks,
                    selectedPriority: _selectedPriority,
                    onSelectPriority: (p) =>
                        setState(() => _selectedPriority = p),
                  ),

                  // ── Task List ────────────────────────────────────────────
                  Expanded(
                    child: tasksAsync.when(
                      loading: () => Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error: $err',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                      data: (_) {
                        if (visibleTasks.isEmpty) {
                          return _EmptyState(
                            selectedPriority: _selectedPriority,
                          );
                        }

                        // Reorderable list when in manual sort mode
                        if (_sortMode == _SortMode.manual) {
                          return ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            itemCount: visibleTasks.length,
                            // ignore: deprecated_member_use
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final item = visibleTasks.removeAt(oldIndex);
                                visibleTasks.insert(newIndex, item);
                                _manualOrderIds = visibleTasks
                                    .map((t) => t.id)
                                    .toList();
                              });
                            },
                            itemBuilder: (context, index) {
                              final task = visibleTasks[index];
                              return _TaskItem(
                                key: ValueKey(task.id),
                                task: task,
                                showDragHandle: true,
                                onToggleStatus: () {
                                  final repo = ref.read(taskRepositoryProvider);
                                  if (task.isCompleted) {
                                    repo.setTaskStatus(
                                      task.id,
                                      TaskStatus.pending,
                                    );
                                  } else {
                                    repo.setTaskStatus(
                                      task.id,
                                      TaskStatus.completed,
                                    );
                                  }
                                },
                                onChangePriority: (newPriority) {
                                  final repo = ref.read(taskRepositoryProvider);
                                  repo.updateTask(
                                    task.copyWith(priority: newPriority),
                                  );
                                },
                              );
                            },
                          );
                        }

                        // Standard list sorted by priority descending
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          itemCount: visibleTasks.length,
                          itemBuilder: (context, index) {
                            final task = visibleTasks[index];
                            return _TaskItem(
                              key: ValueKey(task.id),
                              task: task,
                              showDragHandle: false,
                              onToggleStatus: () {
                                final repo = ref.read(taskRepositoryProvider);
                                if (task.isCompleted) {
                                  repo.setTaskStatus(
                                    task.id,
                                    TaskStatus.pending,
                                  );
                                } else {
                                  repo.setTaskStatus(
                                    task.id,
                                    TaskStatus.completed,
                                  );
                                }
                              },
                              onChangePriority: (newPriority) {
                                final repo = ref.read(taskRepositoryProvider);
                                repo.updateTask(
                                  task.copyWith(priority: newPriority),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Header Bar
// =============================================================================
class _WidgetHeader extends StatelessWidget {
  const _WidgetHeader({
    required this.pendingCount,
    required this.sortMode,
    required this.isAlwaysOnTop,
    required this.collapsed,
    required this.onSelectSortMode,
    required this.onTogglePin,
    required this.onToggleCollapse,
    required this.onOpenApp,
    required this.onClose,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final int pendingCount;
  final _SortMode sortMode;
  final bool isAlwaysOnTop;
  final bool collapsed;
  final ValueChanged<_SortMode> onSelectSortMode;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenApp;
  final VoidCallback onClose;
  final void Function(PointerDeviceKind? kind) onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headerBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => onDragStart(details.kind),
      onPanUpdate: (details) => onDragUpdate(details.delta),
      onPanEnd: (_) => onDragEnd(),
      onPanCancel: onDragEnd,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: headerBg,
          borderRadius: collapsed
              ? BorderRadius.circular(16)
              : const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
          border: Border(
            bottom: collapsed
                ? BorderSide.none
                : BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
          ),
        ),
        child: Row(
          children: [
            // App Brand Icon (Royal Blue)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),

            // App Name
            Flexible(
              child: Text(
                AppConstants.appName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            const Spacer(),

            // Item Counter Badge (only pending tasks remain in the widget)
            Tooltip(
              message: pendingCount == 1
                  ? '1 tarea pendiente'
                  : '$pendingCount tareas pendientes',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Sort Menu Button: Allows user to reorder tasks right from the widget!
            PopupMenuButton<_SortMode>(
              tooltip: 'Ordenar tareas',
              initialValue: sortMode,
              onSelected: onSelectSortMode,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              itemBuilder: (context) => [
                for (final mode in _SortMode.values)
                  PopupMenuItem<_SortMode>(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(
                          mode.icon,
                          size: 15,
                          color: mode == sortMode
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mode.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: mode == sortMode
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: mode == sortMode
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                        if (mode == sortMode) ...[
                          const Spacer(),
                          Icon(
                            Icons.check,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(
                  Icons.sort_rounded,
                  size: 16,
                  color: sortMode != _SortMode.priorityDesc
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // Collapse Button
            _HeaderIconButton(
              icon: collapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              tooltip: collapsed ? 'Expandir' : 'Contraer',
              onTap: onToggleCollapse,
            ),

            // Pin / Always On Top Button
            _HeaderIconButton(
              icon: isAlwaysOnTop
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              tooltip: isAlwaysOnTop ? 'Desfijar' : 'Fijar al frente',
              color: isAlwaysOnTop ? theme.colorScheme.primary : null,
              onTap: onTogglePin,
            ),

            // Open Full App
            _HeaderIconButton(
              icon: Icons.open_in_new_rounded,
              tooltip: 'Abrir app completa',
              onTap: onOpenApp,
            ),

            // Close Widget
            _HeaderIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Cerrar widget',
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 16,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Priority Filter Pills (Supports mouse dragging, mouse wheel, and navigation)
// =============================================================================
class _PriorityFilterPills extends StatefulWidget {
  const _PriorityFilterPills({
    required this.allTasks,
    required this.selectedPriority,
    required this.onSelectPriority,
  });

  final List<Task> allTasks;
  final TaskPriority? selectedPriority;
  final ValueChanged<TaskPriority?> onSelectPriority;

  @override
  State<_PriorityFilterPills> createState() => _PriorityFilterPillsState();
}

class _PriorityFilterPillsState extends State<_PriorityFilterPills> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    int countFor(TaskPriority? p) {
      if (p == null) return widget.allTasks.length;
      return widget.allTasks.where((t) => t.priority == p).length;
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Left chevron button
          InkWell(
            onTap: () => _scroll(-80),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ),

          // Scrollable pills area with mouse drag and mouse wheel support
          Expanded(
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  if (!_scrollController.hasClients) return;
                  final target =
                      (_scrollController.offset + pointerSignal.scrollDelta.dy)
                          .clamp(
                            0.0,
                            _scrollController.position.maxScrollExtent,
                          );
                  _scrollController.jumpTo(target);
                }
              },
              child: ScrollConfiguration(
                behavior: const _DraggableScrollBehavior(),
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  children: [
                    // "Todas" Pill
                    _FilterChip(
                      label: 'Todas',
                      count: countFor(null),
                      isSelected: widget.selectedPriority == null,
                      activeColor: theme.colorScheme.primary,
                      onTap: () => widget.onSelectPriority(null),
                    ),

                    // Priority Pills in descending order: Urgente, Alta, Normal, Baja
                    for (final priority in TaskPriority.values.reversed)
                      _FilterChip(
                        label: priority.label,
                        count: countFor(priority),
                        icon: priority.icon,
                        isSelected: widget.selectedPriority == priority,
                        activeColor: priority.color,
                        onTap: () => widget.onSelectPriority(
                          widget.selectedPriority == priority ? null : priority,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Right chevron button
          InkWell(
            onTap: () => _scroll(80),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
    this.icon,
  });

  final String label;
  final int count;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isSelected
        ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
        : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04));

    final borderColor = isSelected
        ? activeColor.withValues(alpha: 0.6)
        : theme.dividerColor.withValues(alpha: 0.3);

    final textColor = isSelected
        ? activeColor
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: textColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.2)
                        : theme.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: textColor,
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
}

// =============================================================================
// Task Item Widget
// =============================================================================
class _TaskItem extends ConsumerStatefulWidget {
  const _TaskItem({
    super.key,
    required this.task,
    required this.showDragHandle,
    required this.onToggleStatus,
    required this.onChangePriority,
  });

  final Task task;
  final bool showDragHandle;
  final VoidCallback onToggleStatus;
  final ValueChanged<TaskPriority> onChangePriority;

  @override
  ConsumerState<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends ConsumerState<_TaskItem> {
  bool _isHovered = false;
  bool _subtasksExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final task = widget.task;
    final isDone = task.isCompleted;
    final priority = task.priority;

    final cardBg = isDone
        ? (isDark
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.grey.withValues(alpha: 0.1))
        : (_isHovered
              ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white)
              : (isDark
                    ? theme.cardColor.withValues(alpha: 0.45)
                    : theme.cardColor));

    final borderColor = isDone
        ? theme.dividerColor.withValues(alpha: 0.15)
        : (_isHovered
              ? priority.color.withValues(alpha: 0.45)
              : theme.dividerColor.withValues(alpha: 0.35));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Priority Color Accent Bar (Left Edge) ──────────────────
                Container(width: 4, color: priority.color),

                const SizedBox(width: 8),

                // ── Checkbox ───────────────────────────────────────────────
                Center(
                  child: InkWell(
                    onTap: widget.onToggleStatus,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: isDone
                            ? AppColors.success
                            : priority.color.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ── Title & Metadata ───────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: isDone
                                ? theme.hintColor
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        // ── Category pill ──────────────────────────────────
                        if (task.category != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(task.category!.colorValue)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Color(task.category!.colorValue)
                                        .withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.label_rounded,
                                      size: 9,
                                      color: Color(task.category!.colorValue),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      task.category!.name,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(task.category!.colorValue),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (task.dueDate != null) ...[
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 10,
                                color: task.isOverdue && !isDone
                                    ? AppColors.danger
                                    : theme.hintColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                DateFormatter.formatDueDate(task.dueDate),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: task.isOverdue && !isDone
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: task.isOverdue && !isDone
                                      ? AppColors.danger
                                      : theme.hintColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (task.subtasks.isNotEmpty) ...[
                              GestureDetector(
                                onTap: () => setState(
                                  () => _subtasksExpanded = !_subtasksExpanded,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 11,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${task.completedSubtasks}/${task.subtasks.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    AnimatedRotation(
                                      turns: _subtasksExpanded ? 0.5 : 0,
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 12,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        // ── Inline subtask list ───────────────────────────
                        if (task.subtasks.isNotEmpty)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: _subtasksExpanded
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      ...task.subtasks.map(
                                        (s) => _WidgetSubtaskRow(
                                          subtask: s,
                                          onToggle: () {
                                            ref
                                                .read(subtaskRepositoryProvider)
                                                .setSubtaskCompleted(
                                                  s.id,
                                                  !s.isCompleted,
                                                );
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Priority Badge & Quick Reassignment Menu ───────────────
                Center(
                  child: PopupMenuButton<TaskPriority>(
                    tooltip: 'Cambiar prioridad (reubicar tarea)',
                    initialValue: priority,
                    onSelected: widget.onChangePriority,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    itemBuilder: (context) => [
                      for (final p in TaskPriority.values.reversed)
                        PopupMenuItem<TaskPriority>(
                          value: p,
                          child: Row(
                            children: [
                              Icon(p.icon, size: 14, color: p.color),
                              const SizedBox(width: 8),
                              Text(
                                p.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: p == priority
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: p.color,
                                ),
                              ),
                              if (p == priority) ...[
                                const Spacer(),
                                Icon(Icons.check, size: 14, color: p.color),
                              ],
                            ],
                          ),
                        ),
                    ],
                    child: Container(
                      margin: EdgeInsets.only(
                        right: widget.showDragHandle ? 2 : 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: priority.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: priority.color.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(priority.icon, size: 11, color: priority.color),
                          const SizedBox(width: 3),
                          Text(
                            priority.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priority.color,
                            ),
                          ),
                          const SizedBox(width: 1),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 13,
                            color: priority.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Drag Handle (in manual sort mode) ──────────────────────
                if (widget.showDragHandle)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
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
}

// =============================================================================
// Widget Subtask Row (inline in widget)
// =============================================================================
class _WidgetSubtaskRow extends StatelessWidget {
  const _WidgetSubtaskRow({required this.subtask, required this.onToggle});

  final Subtask subtask;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDone = subtask.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isDone
                        ? AppColors.success
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.3)),
                    width: 1.4,
                  ),
                ),
                child: isDone
                    ? Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: AppColors.success,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtask.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? theme.hintColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.85),
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

// =============================================================================
// Empty State
// =============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.selectedPriority});

  final TaskPriority? selectedPriority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all_rounded,
            size: 40,
            color: AppColors.success.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            selectedPriority == null
                ? '¡Sin tareas pendientes!'
                : 'Sin tareas con prioridad ${selectedPriority!.label}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Buen trabajo',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
