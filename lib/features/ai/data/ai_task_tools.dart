import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/core/errors/app_exception.dart';
import 'package:task_check/features/categories/domain/category.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_repository.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:uuid/uuid.dart';

/// Puente entre el modelo de Gemini y la base de datos de TaskCheck.
///
/// Cada herramienta devuelve un mapa serializable que Gemini recibe como
/// `functionResponse`. Los errores se devuelven como `{'error': ...}` para que
/// el modelo pueda explicarle al usuario qué pasó en lugar de fallar.
class AiTaskTools {
  AiTaskTools({
    required AppDatabase database,
    required TaskRepository taskRepository,
    Uuid? uuid,
  }) : _db = database,
       _tasks = taskRepository,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final TaskRepository _tasks;
  final Uuid _uuid;

  /// Declaraciones enviadas a Gemini en cada petición.
  static const List<Map<String, dynamic>> declarations = [
    {
      'name': 'obtener_resumen',
      'description':
          'Resumen general de la base de datos: totales de tareas por estado, '
          'vencidas, de hoy, archivadas, bloqueadas y la lista de categorías. '
          'Úsala para preguntas generales o de estadísticas.',
    },
    {
      'name': 'listar_tareas',
      'description':
          'Lista tareas con todos sus datos: id, título, descripción, estado, '
          'prioridad, categoría, fecha de vencimiento, subtareas y si están '
          'bloqueadas. Devuelve las tareas activas por defecto.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'estado': {
            'type': 'STRING',
            'enum': ['pendiente', 'en_progreso', 'completada', 'todas'],
            'description': 'Filtra por estado. "todas" no filtra por estado.',
          },
          'prioridad': {
            'type': 'STRING',
            'enum': ['baja', 'normal', 'alta', 'urgente'],
            'description': 'Filtra por prioridad.',
          },
          'categoria': {
            'type': 'STRING',
            'description':
                'Nombre exacto de la categoría (sin distinguir '
                'mayúsculas).',
          },
          'buscar': {
            'type': 'STRING',
            'description': 'Texto a buscar en el título o la descripción.',
          },
          'solo_vencidas': {
            'type': 'BOOLEAN',
            'description': 'Devuelve solo tareas cuya fecha ya pasó.',
          },
          'vencen_antes_de': {
            'type': 'STRING',
            'description':
                'Fecha límite en formato YYYY-MM-DD; solo tareas que vencen '
                'ese día o antes.',
          },
          'incluir_archivadas': {
            'type': 'BOOLEAN',
            'description': 'Incluye las tareas archivadas. Por defecto false.',
          },
          'limite': {
            'type': 'INTEGER',
            'description': 'Máximo de tareas a devolver (por defecto 50).',
          },
        },
      },
    },
    {
      'name': 'obtener_tarea',
      'description': 'Devuelve el detalle completo de una tarea por su id.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'id': {'type': 'STRING', 'description': 'Id de la tarea.'},
        },
        'required': ['id'],
      },
    },
    {
      'name': 'crear_tarea',
      'description':
          'Crea una tarea nueva. Si la categoría indicada no existe se crea '
          'automáticamente.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'titulo': {'type': 'STRING', 'description': 'Título de la tarea.'},
          'descripcion': {
            'type': 'STRING',
            'description': 'Descripción larga.',
          },
          'prioridad': {
            'type': 'STRING',
            'enum': ['baja', 'normal', 'alta', 'urgente'],
            'description': 'Prioridad; por defecto normal.',
          },
          'categoria': {
            'type': 'STRING',
            'description': 'Nombre de la categoría.',
          },
          'vence': {
            'type': 'STRING',
            'description':
                'Fecha de vencimiento en formato YYYY-MM-DD (se interpreta '
                'como fin de ese día) o fecha y hora ISO 8601.',
          },
          'subtareas': {
            'type': 'ARRAY',
            'items': {'type': 'STRING'},
            'description': 'Lista de subtareas a crear con la tarea.',
          },
        },
        'required': ['titulo'],
      },
    },
    {
      'name': 'actualizar_tarea',
      'description':
          'Modifica una tarea existente. Solo cambia los campos que se envían. '
          'Las tareas completadas hace más de 4 horas están bloqueadas.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'id': {'type': 'STRING', 'description': 'Id de la tarea.'},
          'titulo': {'type': 'STRING'},
          'descripcion': {'type': 'STRING'},
          'prioridad': {
            'type': 'STRING',
            'enum': ['baja', 'normal', 'alta', 'urgente'],
          },
          'categoria': {'type': 'STRING'},
          'vence': {
            'type': 'STRING',
            'description': 'Nueva fecha en formato YYYY-MM-DD o ISO 8601.',
          },
          'estado': {
            'type': 'STRING',
            'enum': ['pendiente', 'en_progreso', 'completada'],
          },
        },
        'required': ['id'],
      },
    },
    {
      'name': 'cambiar_estado',
      'description':
          'Cambia el estado de una tarea: pendiente, en_progreso o completada.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'id': {'type': 'STRING', 'description': 'Id de la tarea.'},
          'estado': {
            'type': 'STRING',
            'enum': ['pendiente', 'en_progreso', 'completada'],
          },
        },
        'required': ['id', 'estado'],
      },
    },
    {
      'name': 'archivar_tarea',
      'description':
          'Archiva o restaura una tarea. Archivar siempre está permitido, '
          'incluso si la tarea está bloqueada.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'id': {'type': 'STRING', 'description': 'Id de la tarea.'},
          'archivar': {
            'type': 'BOOLEAN',
            'description': 'true para archivar, false para restaurar.',
          },
        },
        'required': ['id'],
      },
    },
    {
      'name': 'eliminar_tarea',
      'description':
          'Elimina una tarea y sus subtareas de forma permanente. No se puede '
          'usar con tareas bloqueadas.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'id': {'type': 'STRING', 'description': 'Id de la tarea.'},
        },
        'required': ['id'],
      },
    },
    {
      'name': 'listar_categorias',
      'description': 'Lista las categorías con cuántas tareas activas tienen.',
    },
  ];

  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (name) {
        case 'obtener_resumen':
          return await _overview();
        case 'listar_tareas':
          return await _listTasks(args);
        case 'obtener_tarea':
          return await _getTask(args);
        case 'crear_tarea':
          return await _createTask(args);
        case 'actualizar_tarea':
          return await _updateTask(args);
        case 'cambiar_estado':
          return await _changeStatus(args);
        case 'archivar_tarea':
          return await _archiveTask(args);
        case 'eliminar_tarea':
          return await _deleteTask(args);
        case 'listar_categorias':
          return await _listCategories();
        default:
          return {'error': 'Herramienta desconocida: $name'};
      }
    } on TaskLockedException catch (error) {
      return {'error': error.message};
    } on AppException catch (error) {
      return {'error': error.message};
    } catch (error) {
      return {'error': 'No se pudo completar la operación: $error'};
    }
  }

  // ==================== HERRAMIENTAS ====================

  Future<Map<String, dynamic>> _overview() async {
    final tasks = await _allTasks();
    final categories = await _db.getAllCategories();
    final active = tasks.where((task) => !task.isArchived).toList();

    return {
      'fecha_actual': DateTime.now().toIso8601String(),
      'total_tareas': tasks.length,
      'activas': active.length,
      'pendientes': active
          .where((task) => task.status == TaskStatus.pending)
          .length,
      'en_progreso': active
          .where((task) => task.status == TaskStatus.inProgress)
          .length,
      'completadas': active
          .where((task) => task.status == TaskStatus.completed)
          .length,
      'archivadas': tasks.where((task) => task.isArchived).length,
      'vencidas': active.where((task) => task.isOverdue).length,
      'vence_hoy': active
          .where((task) => task.isDueToday && !task.isCompleted)
          .length,
      'prioridad_alta_o_urgente_pendientes': active
          .where(
            (task) =>
                !task.isCompleted &&
                (task.priority == TaskPriority.high ||
                    task.priority == TaskPriority.urgent),
          )
          .length,
      'sin_categoria': active.where((task) => task.categoryId == null).length,
      'bloqueadas': tasks.where((task) => task.isCompletionLocked).length,
      'categorias': [
        for (final category in categories)
          {
            'id': category.id,
            'nombre': category.name,
            'tareas_activas': active
                .where((task) => task.categoryId == category.id)
                .length,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _listTasks(Map<String, dynamic> args) async {
    final status = _statusFrom(_string(args, 'estado'));
    final priority = _priorityFrom(_string(args, 'prioridad'));
    final categoryName = _string(args, 'categoria')?.toLowerCase();
    final search = _string(args, 'buscar')?.toLowerCase();
    final includeArchived = _bool(args, 'incluir_archivadas') ?? false;
    final onlyOverdue = _bool(args, 'solo_vencidas') ?? false;
    final before = _parseDate(args['vencen_antes_de']);
    final limit = (_int(args, 'limite') ?? 50).clamp(1, 200);

    Set<String>? categoryIds;
    if (categoryName != null) {
      final categories = await _db.getAllCategories();
      categoryIds = categories
          .where(
            (category) => category.name.toLowerCase().contains(categoryName),
          )
          .map((category) => category.id)
          .toSet();
      if (categoryIds.isEmpty) {
        return {
          'error':
              'No existe una categoría llamada "$categoryName". '
              'Disponibles: ${categories.map((c) => c.name).join(', ')}.',
        };
      }
    }

    final tasks = await _allTasks();
    final filtered = tasks.where((task) {
      if (!includeArchived && task.isArchived) return false;
      if (status != null && task.status != status) return false;
      if (priority != null && task.priority != priority) return false;
      if (categoryIds != null && !categoryIds.contains(task.categoryId)) {
        return false;
      }
      if (search != null) {
        final haystack = '${task.title} ${task.description ?? ''}'
            .toLowerCase();
        if (!haystack.contains(search)) return false;
      }
      if (onlyOverdue && !task.isOverdue) return false;
      if (before != null &&
          (task.dueDate == null || task.dueDate!.isAfter(before))) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final byPriority = b.priority.value.compareTo(a.priority.value);
      if (byPriority != 0) return byPriority;
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue == null) return 0;
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });

    final limited = filtered.take(limit).toList();
    return {
      'total_coincidencias': filtered.length,
      'mostradas': limited.length,
      'tareas': limited.map(_taskToJson).toList(),
    };
  }

  Future<Map<String, dynamic>> _getTask(Map<String, dynamic> args) async {
    final id = _string(args, 'id');
    if (id == null) return {'error': 'Falta el id de la tarea.'};

    final task = await _db.getTaskById(id);
    if (task == null) return {'error': 'No existe una tarea con ese id.'};
    return {'tarea': _taskToJson(task)};
  }

  Future<Map<String, dynamic>> _createTask(Map<String, dynamic> args) async {
    final title = _string(args, 'titulo');
    if (title == null) return {'error': 'Falta el título de la tarea.'};

    final category = await _resolveCategory(_string(args, 'categoria'));
    final now = DateTime.now();
    final subtaskTitles = _stringList(args, 'subtareas');
    final taskId = _uuid.v4();

    final task = Task(
      id: taskId,
      title: title,
      description: _string(args, 'descripcion'),
      priority:
          _priorityFrom(_string(args, 'prioridad')) ?? TaskPriority.normal,
      categoryId: category?.id,
      dueDate: _parseDate(args['vence']),
      createdAt: now,
      updatedAt: now,
      category: category,
      subtasks: [
        for (var index = 0; index < subtaskTitles.length; index++)
          Subtask(
            id: _uuid.v4(),
            taskId: taskId,
            title: subtaskTitles[index],
            createdAt: now,
            sortOrder: index,
          ),
      ],
    );

    await _tasks.createTask(task);

    return {
      'ok': true,
      'mensaje': 'Tarea creada correctamente.',
      'tarea': _taskToJson(task),
    };
  }

  Future<Map<String, dynamic>> _updateTask(Map<String, dynamic> args) async {
    final id = _string(args, 'id');
    if (id == null) return {'error': 'Falta el id de la tarea.'};

    final existing = await _db.getTaskById(id);
    if (existing == null) return {'error': 'No existe una tarea con ese id.'};

    final statusValue = _string(args, 'estado');
    final status = statusValue == null ? null : _statusFrom(statusValue);

    Category? category;
    var replaceCategory = false;
    if (_string(args, 'categoria') != null) {
      category = await _resolveCategory(_string(args, 'categoria'));
      replaceCategory = true;
    }

    final updated = existing.copyWith(
      title: _string(args, 'titulo'),
      description: _string(args, 'descripcion'),
      priority: _priorityFrom(_string(args, 'prioridad')),
      status: status,
      categoryId: replaceCategory ? category?.id : null,
      category: replaceCategory ? category : null,
      dueDate: _parseDate(args['vence']),
      updatedAt: DateTime.now(),
    );

    await _tasks.updateTask(updated);

    return {
      'ok': true,
      'mensaje': 'Tarea actualizada.',
      'tarea': _taskToJson(updated),
    };
  }

  Future<Map<String, dynamic>> _changeStatus(Map<String, dynamic> args) async {
    final id = _string(args, 'id');
    if (id == null) return {'error': 'Falta el id de la tarea.'};

    final status = _statusFrom(_string(args, 'estado'));
    if (status == null) {
      return {
        'error': 'Estado no válido. Usa: pendiente, en_progreso o completada.',
      };
    }

    await _tasks.setTaskStatus(id, status);
    final task = await _db.getTaskById(id);
    if (task == null) return {'error': 'No existe una tarea con ese id.'};

    return {
      'ok': true,
      'mensaje': 'Estado cambiado a "${status.label}".',
      'tarea': _taskToJson(task),
    };
  }

  Future<Map<String, dynamic>> _archiveTask(Map<String, dynamic> args) async {
    final id = _string(args, 'id');
    if (id == null) return {'error': 'Falta el id de la tarea.'};

    final archive = _bool(args, 'archivar') ?? true;
    await _tasks.setTaskArchived(id, archive);

    return {
      'ok': true,
      'mensaje': archive ? 'Tarea archivada.' : 'Tarea restaurada.',
      'archivada': archive,
    };
  }

  Future<Map<String, dynamic>> _deleteTask(Map<String, dynamic> args) async {
    final id = _string(args, 'id');
    if (id == null) return {'error': 'Falta el id de la tarea.'};

    final task = await _db.getTaskById(id);
    if (task == null) return {'error': 'No existe una tarea con ese id.'};

    await _tasks.deleteTask(id);
    return {'ok': true, 'mensaje': 'Tarea eliminada: "${task.title}".'};
  }

  Future<Map<String, dynamic>> _listCategories() async {
    final categories = await _db.getAllCategories();
    final tasks = await _allTasks();
    final active = tasks.where((task) => !task.isArchived).toList();

    return {
      'categorias': [
        for (final category in categories)
          {
            'id': category.id,
            'nombre': category.name,
            'tareas_activas': active
                .where((task) => task.categoryId == category.id)
                .length,
          },
      ],
    };
  }

  // ==================== APOYO ====================

  Future<List<Task>> _allTasks() => _db.watchTasksWithDetails().first;

  Future<Category?> _resolveCategory(String? name) async {
    if (name == null) return null;

    final categories = await _db.getAllCategories();
    for (final category in categories) {
      if (category.name.toLowerCase() == name.toLowerCase()) return category;
    }

    final now = DateTime.now();
    final created = Category(
      id: _uuid.v4(),
      name: name,
      colorValue: 0xFF6366F1,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertCategory(created);
    _db.syncFromDisk();
    return created;
  }

  Map<String, dynamic> _taskToJson(Task task) {
    return {
      'id': task.id,
      'titulo': task.title,
      'descripcion': task.description,
      'estado': _statusCode(task.status),
      'prioridad': _priorityCode(task.priority),
      'categoria': task.category?.name,
      'vence': task.dueDate?.toIso8601String(),
      'creada': task.createdAt.toIso8601String(),
      'completada': task.completedAt?.toIso8601String(),
      'archivada': task.isArchived,
      'bloqueada': task.isCompletionLocked,
      'subtareas': [
        for (final subtask in task.subtasks)
          {
            'id': subtask.id,
            'titulo': subtask.title,
            'completada': subtask.isCompleted,
          },
      ],
      'progreso_subtareas': '${task.completedSubtasks}/${task.totalSubtasks}',
    };
  }

  static String _statusCode(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'pendiente';
      case TaskStatus.inProgress:
        return 'en_progreso';
      case TaskStatus.completed:
        return 'completada';
    }
  }

  static String _priorityCode(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'baja';
      case TaskPriority.normal:
        return 'normal';
      case TaskPriority.high:
        return 'alta';
      case TaskPriority.urgent:
        return 'urgente';
    }
  }

  static TaskStatus? _statusFrom(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'pendiente':
        return TaskStatus.pending;
      case 'en_progreso':
      case 'en progreso':
        return TaskStatus.inProgress;
      case 'completada':
      case 'completado':
        return TaskStatus.completed;
      default:
        return null;
    }
  }

  static TaskPriority? _priorityFrom(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'baja':
        return TaskPriority.low;
      case 'normal':
        return TaskPriority.normal;
      case 'alta':
        return TaskPriority.high;
      case 'urgente':
        return TaskPriority.urgent;
      default:
        return null;
    }
  }

  /// Acepta `YYYY-MM-DD` (se interpreta como el final de ese día) o ISO 8601.
  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final raw = value.trim();
    if (raw.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return DateTime.tryParse('${raw}T23:59:00');
    }
    return DateTime.tryParse(raw);
  }

  static String? _string(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static bool? _bool(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == 'si' || normalized == 'sí') {
        return true;
      }
      if (normalized == 'false' || normalized == 'no') return false;
    }
    return null;
  }

  static int? _int(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static List<String> _stringList(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }
}
