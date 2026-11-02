import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/features/subtasks/domain/subtask.dart';

void main() {
  group('Subtask Domain Model Tests', () {
    final now = DateTime.now();

    test('Creates valid Subtask instance with defaults', () {
      final subtask = Subtask(
        id: 's-1',
        taskId: 't-1',
        title: 'Revisar documentación',
        createdAt: now,
      );

      expect(subtask.id, 's-1');
      expect(subtask.taskId, 't-1');
      expect(subtask.title, 'Revisar documentación');
      expect(subtask.isCompleted, isFalse);
      expect(subtask.sortOrder, 0);
    });

    test('copyWith modifies completed status and title correctly', () {
      final subtask = Subtask(
        id: 's-1',
        taskId: 't-1',
        title: 'Original',
        createdAt: now,
      );

      final completed = subtask.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
      expect(completed.title, 'Original');

      final renamed = completed.copyWith(title: 'Nuevo título');
      expect(renamed.title, 'Nuevo título');
      expect(renamed.isCompleted, isTrue);
    });

    test('Equality and hashCode verify values properly', () {
      final s1 = Subtask(
        id: 's-1',
        taskId: 't-1',
        title: 'A',
        isCompleted: false,
        createdAt: now,
      );
      final s2 = Subtask(
        id: 's-1',
        taskId: 't-1',
        title: 'A',
        isCompleted: false,
        createdAt: now,
      );
      final s3 = Subtask(
        id: 's-2',
        taskId: 't-1',
        title: 'A',
        isCompleted: false,
        createdAt: now,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
    });
  });
}
