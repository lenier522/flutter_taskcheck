import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:task_check/features/tasks/domain/task.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';
import 'package:task_check/features/tasks/domain/task_status.dart';
import 'package:task_check/features/tasks/presentation/widgets/task_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  testWidgets('TaskCard displays title, priority badge and status checkbox', (
    tester,
  ) async {
    final now = DateTime.now();
    final task = Task(
      id: 'tc-1',
      title: 'Comprar insumos de oficina',
      description: 'Papel, tinta y grapas',
      priority: TaskPriority.urgent,
      status: TaskStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: TaskCard(task: task)),
        ),
      ),
    );

    // Verify task title is rendered
    expect(find.text('Comprar insumos de oficina'), findsOneWidget);

    // Verify priority label is rendered
    expect(find.text('Urgente'), findsOneWidget);

    // Verify checkbox is rendered
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
