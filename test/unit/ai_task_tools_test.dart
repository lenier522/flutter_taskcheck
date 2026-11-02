import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/core/database/app_database.dart';
import 'package:task_check/features/ai/data/ai_task_tools.dart';
import 'package:task_check/features/tasks/data/task_repository_impl.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';

void main() {
  late AppDatabase db;
  late AiTaskTools tools;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tools = AiTaskTools(database: db, taskRepository: TaskRepositoryImpl(db));
  });

  tearDown(() async => db.close());

  test(
    'crear_tarea guarda prioridad, vencimiento, categoría y subtareas',
    () async {
      final result = await tools.execute('crear_tarea', {
        'titulo': 'Estudiar alemán',
        'prioridad': 'alta',
        'categoria': 'Idiomas',
        'vence': '2026-11-05',
        'subtareas': ['Lección 1', 'Lección 2'],
      });

      expect(result['ok'], isTrue);
      final task = result['tarea'] as Map<String, dynamic>;
      expect(task['titulo'], 'Estudiar alemán');
      expect(task['prioridad'], 'alta');
      expect(task['categoria'], 'Idiomas');
      expect((task['subtareas'] as List).length, 2);
      expect(task['vence'], startsWith('2026-11-05'));

      final listed = await tools.execute('listar_tareas', {
        'categoria': 'Idiomas',
      });
      expect(listed['total_coincidencias'], 1);
    },
  );

  test(
    'listar_tareas filtra por estado y excluye archivar por defecto',
    () async {
      final first = await tools.execute('crear_tarea', {'titulo': 'Pendiente'});
      final second = await tools.execute('crear_tarea', {
        'titulo': 'Archivada',
      });

      await tools.execute('cambiar_estado', {
        'id': (first['tarea'] as Map)['id'],
        'estado': 'completada',
      });
      await tools.execute('archivar_tarea', {
        'id': (second['tarea'] as Map)['id'],
      });

      final pending = await tools.execute('listar_tareas', {
        'estado': 'pendiente',
      });
      expect(pending['total_coincidencias'], 0);

      final completed = await tools.execute('listar_tareas', {
        'estado': 'completada',
      });
      expect(completed['total_coincidencias'], 1);

      final everything = await tools.execute('listar_tareas', {
        'incluir_archivadas': true,
        'estado': 'todas',
      });
      expect(everything['total_coincidencias'], 2);
    },
  );

  test(
    'eliminar_tarea rechaza tareas bloqueadas con un mensaje claro',
    () async {
      final now = DateTime.now();
      await db.insertTask(
        Task(
          id: 'locked-task',
          title: 'Tarea antigua',
          status: TaskStatus.completed,
          createdAt: now,
          updatedAt: now,
          completedAt: now.subtract(const Duration(hours: 5)),
        ),
      );

      final result = await tools.execute('eliminar_tarea', {
        'id': 'locked-task',
      });

      expect(result['error'], contains('4 horas'));
      expect(await db.getTaskById('locked-task'), isNotNull);

      final archived = await tools.execute('archivar_tarea', {
        'id': 'locked-task',
      });
      expect(archived['ok'], isTrue);
    },
  );

  test('catálogo de herramientas declara nombre y parámetros válidos', () {
    expect(AiTaskTools.declarations, isNotEmpty);

    for (final declaration in AiTaskTools.declarations) {
      expect(declaration['name'], isA<String>());
      expect(declaration['description'], isA<String>());
      final parameters = declaration['parameters'];
      if (parameters != null) {
        expect((parameters as Map)['type'], 'OBJECT');
      }
    }
  });
}
