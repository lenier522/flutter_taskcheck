import 'package:flutter_test/flutter_test.dart';
import 'package:task_check/features/categories/domain/category.dart';

void main() {
  group('Category Domain Model Tests', () {
    final now = DateTime.now();

    test('Creates valid Category instance with defaults', () {
      final category = Category(
        id: 'c-1',
        name: 'Trabajo',
        colorValue: 0xFF2563EB,
        createdAt: now,
        updatedAt: now,
      );

      expect(category.id, 'c-1');
      expect(category.name, 'Trabajo');
      expect(category.colorValue, 0xFF2563EB);
    });

    test('copyWith renames and changes color', () {
      final category = Category(
        id: 'c-1',
        name: 'Trabajo',
        colorValue: 0xFF2563EB,
        createdAt: now,
        updatedAt: now,
      );

      final updated = category.copyWith(
        name: 'Personal',
        colorValue: 0xFF10B981,
      );

      expect(updated.id, 'c-1');
      expect(updated.name, 'Personal');
      expect(updated.colorValue, 0xFF10B981);
    });

    test('Equality and hashCode match for identical properties', () {
      final c1 = Category(
        id: 'c-1',
        name: 'A',
        colorValue: 123,
        createdAt: now,
        updatedAt: now,
      );
      final c2 = Category(
        id: 'c-1',
        name: 'A',
        colorValue: 123,
        createdAt: now,
        updatedAt: now,
      );

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
    });
  });
}
