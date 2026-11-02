import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:task_check/core/utils/date_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  group('DateFormatter Tests', () {
    test('Formats null date as "Sin fecha"', () {
      expect(DateFormatter.formatDueDate(null), 'Sin fecha');
    });

    test('Formats today date with prefix "Hoy"', () {
      final now = DateTime.now();
      final todayNoTime = DateTime(now.year, now.month, now.day);
      expect(DateFormatter.formatDueDate(todayNoTime).trim(), 'Hoy');
    });

    test('Formats tomorrow date with prefix "Mañana"', () {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      expect(DateFormatter.formatDueDate(tomorrow).trim(), 'Mañana');
    });

    test('Formats yesterday date with prefix "Ayer"', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      expect(DateFormatter.formatDueDate(yesterday), 'Ayer');
    });

    test('Formats overdue date with "Vencida hace X días"', () {
      final now = DateTime.now();
      final past = DateTime(now.year, now.month, now.day - 4);
      expect(DateFormatter.formatDueDate(past), 'Vencida hace 4 días');
    });

    test('formatFullDate formats correctly', () {
      final date = DateTime(2026, 5, 10);
      final result = DateFormatter.formatFullDate(date);
      expect(result.contains('10'), isTrue);
      expect(result.contains('2026'), isTrue);
    });
  });
}
