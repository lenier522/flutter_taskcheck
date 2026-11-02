import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_check/core/config/app_env.dart';
import 'package:task_check/core/providers.dart';
import 'package:task_check/features/ai/data/ai_task_tools.dart';
import 'package:task_check/features/ai/data/gemini_client.dart';
import 'package:task_check/features/ai/domain/ai_chat_message.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

/// Estado visible del chat.
class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isSending = false,
    this.activity,
  });

  final List<AiChatMessage> messages;
  final bool isSending;

  /// Texto de progreso mientras la IA consulta la aplicación.
  final String? activity;

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isSending,
    String? activity,
    bool clearActivity = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      activity: clearActivity ? null : (activity ?? this.activity),
    );
  }
}

final aiChatControllerProvider =
    NotifierProvider<AiChatController, AiChatState>(AiChatController.new);

/// Orquesta la conversación: mantiene el historial para Gemini, ejecuta las
/// funciones que el modelo solicite y publica los mensajes para la interfaz.
class AiChatController extends Notifier<AiChatState> {
  static const int _maxRounds = 6;
  static const int _maxContents = 40;

  static const List<String> _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const List<String> _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// Historial en el formato nativo de Gemini (incluye llamadas a funciones).
  final List<Map<String, dynamic>> _contents = [];

  GeminiClient? _client;
  AiTaskTools? _tools;

  @override
  AiChatState build() => const AiChatState();

  GeminiClient get _gemini => _client ??= GeminiClient();

  AiTaskTools get _taskTools => _tools ??= AiTaskTools(
    database: ref.read(appDatabaseProvider),
    taskRepository: ref.read(taskRepositoryProvider),
  );

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isSending) return;

    if (!AppEnv.hasGeminiApiKey) {
      _append(
        AiChatMessage.assistant(
          'No encontré tu clave de Gemini. Crea un archivo .env con la línea '
          'GEMINI_API_KEY=tu_clave en alguna de estas rutas:\n\n'
          '${AppEnv.searchedPaths.join('\n')}',
          isError: true,
        ),
      );
      return;
    }

    state = state.copyWith(
      messages: [...state.messages, AiChatMessage.user(text)],
      isSending: true,
      activity: 'Pensando…',
    );
    _contents.add({
      'role': 'user',
      'parts': [
        {'text': text},
      ],
    });

    try {
      final systemInstruction = await _systemInstruction();

      for (var round = 0; round < _maxRounds; round++) {
        final response = await _gemini.generate(
          systemInstruction: systemInstruction,
          contents: _contents,
          tools: AiTaskTools.declarations,
        );

        if (!response.hasCalls) {
          final reply = response.text.trim();
          final visible = reply.isEmpty ? 'Listo.' : reply;
          _contents.add({
            'role': 'model',
            'parts': [
              {'text': visible},
            ],
          });
          _append(AiChatMessage.assistant(visible));
          state = state.copyWith(isSending: false, clearActivity: true);
          return;
        }

        final modelParts = <Map<String, dynamic>>[
          for (final call in response.calls)
            {
              'functionCall': {'name': call.name, 'args': call.args},
            },
        ];
        if (response.text.trim().isNotEmpty) {
          modelParts.add({'text': response.text.trim()});
        }
        _contents.add({'role': 'model', 'parts': modelParts});

        final responses = <Map<String, dynamic>>[];
        for (final call in response.calls) {
          state = state.copyWith(activity: _activityFor(call.name));
          final result = await _taskTools.execute(call.name, call.args);
          responses.add({
            'functionResponse': {'name': call.name, 'response': result},
          });
        }
        _contents.add({'role': 'user', 'parts': responses});
        _trimContents();
      }

      _append(
        AiChatMessage.assistant(
          'Necesité demasiadas consultas para responder. ¿Puedes reformular la '
          'pregunta de forma más concreta?',
          isError: true,
        ),
      );
      state = state.copyWith(isSending: false, clearActivity: true);
    } catch (error) {
      final message = error is AiException
          ? error.message
          : 'Ocurrió un error al hablar con la IA:\n$error';
      _append(AiChatMessage.assistant(message, isError: true));
      state = state.copyWith(isSending: false, clearActivity: true);
    }
  }

  void clear() {
    _contents.clear();
    state = const AiChatState();
  }

  void _append(AiChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Evita que la conversación crezca sin límite y que queden respuestas de
  /// función sin su llamada correspondiente.
  void _trimContents() {
    while (_contents.length > _maxContents) {
      _contents.removeAt(0);
    }
    while (_contents.isNotEmpty && _hasFunctionResponse(_contents.first)) {
      _contents.removeAt(0);
    }
  }

  bool _hasFunctionResponse(Map<String, dynamic> content) {
    final parts = content['parts'];
    if (parts is! List) return false;
    return parts.any(
      (part) => part is Map && part.containsKey('functionResponse'),
    );
  }

  Future<String> _systemInstruction() async {
    final buffer = StringBuffer()
      ..writeln(
        'Eres el asistente personal de TaskCheck, una aplicación de escritorio '
        'para gestionar tareas, prioridades y categorías.',
      )
      ..writeln(
        'Tienes acceso completo a la base de datos de la aplicación mediante '
        'herramientas (funciones).',
      )
      ..writeln('Fecha y hora actual: ${_describeNow(DateTime.now())}.')
      ..writeln()
      ..writeln('Reglas:')
      ..writeln(
        '- Consulta con las herramientas antes de responder sobre tareas, '
        'fechas, prioridades o estadísticas. Nunca inventes datos.',
      )
      ..writeln(
        '- Si el usuario pide crear, cambiar, completar, archivar o eliminar '
        'algo, hazlo con las herramientas y luego resume en una línea lo hecho.',
      )
      ..writeln(
        '- No elimines tareas sin confirmación explícita del usuario en la '
        'conversación.',
      )
      ..writeln(
        '- Las tareas completadas hace más de 4 horas están bloqueadas: no se '
        'pueden editar, desmarcar ni eliminar, pero sí archivar. Si una '
        'herramienta devuelve ese error, explícalo con naturalidad.',
      )
      ..writeln(
        '- Responde en español, breve y ordenado. Usa listas cortas cuando '
        'ayuden a leer varios elementos. No muestres ids internos salvo que el '
        'usuario los pida.',
      )
      ..writeln(
        '- Cuando el usuario diga "hoy", "mañana" o "esta semana", parte de la '
        'fecha actual indicada arriba.',
      )
      ..writeln()
      ..writeln('Contexto actual de la base de datos:');

    try {
      final database = ref.read(appDatabaseProvider);
      final tasks = await database.watchTasksWithDetails().first;
      final categories = await database.getAllCategories();
      final active = tasks.where((task) => !task.isArchived).toList();

      buffer
        ..writeln(
          '- Tareas activas: ${active.length} '
          '(pendientes: ${active.where((t) => t.status == TaskStatus.pending).length}, '
          'en progreso: ${active.where((t) => t.status == TaskStatus.inProgress).length}, '
          'completadas: ${active.where((t) => t.status == TaskStatus.completed).length})',
        )
        ..writeln('- Archivadas: ${tasks.where((t) => t.isArchived).length}')
        ..writeln(
          '- Vencidas: ${active.where((t) => t.isOverdue).length} · '
          'Vencen hoy: ${active.where((t) => t.isDueToday && !t.isCompleted).length}',
        )
        ..writeln(
          '- Alta o urgente sin terminar: ${active.where((t) => !t.isCompleted && (t.priority == TaskPriority.high || t.priority == TaskPriority.urgent)).length}',
        )
        ..writeln(
          '- Categorías: ${categories.isEmpty ? 'ninguna' : categories.map((c) => c.name).join(', ')}',
        )
        ..writeln()
        ..writeln(
          'Usa "listar_tareas" para ver el detalle; el resumen no incluye el '
          'contenido de cada tarea.',
        );
    } catch (error) {
      buffer.writeln('- No se pudo leer el resumen: $error');
    }

    return buffer.toString();
  }

  String _describeNow(DateTime now) {
    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$weekday ${now.day} de $month de ${now.year}, $hour:$minute';
  }

  String _activityFor(String tool) {
    switch (tool) {
      case 'obtener_resumen':
        return 'Revisando tus estadísticas…';
      case 'listar_tareas':
      case 'obtener_tarea':
        return 'Consultando tus tareas…';
      case 'crear_tarea':
        return 'Creando la tarea…';
      case 'actualizar_tarea':
      case 'cambiar_estado':
        return 'Actualizando la tarea…';
      case 'archivar_tarea':
        return 'Archivando la tarea…';
      case 'eliminar_tarea':
        return 'Eliminando la tarea…';
      case 'listar_categorias':
        return 'Revisando tus categorías…';
      default:
        return 'Consultando la aplicación…';
    }
  }
}
