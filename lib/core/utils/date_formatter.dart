import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateFormat = DateFormat('d MMM yyyy', 'es');
  static final DateFormat _shortDateFormat = DateFormat('d MMM', 'es');

  static String formatDueDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = target.difference(today).inDays;

    final timeStr = _timeFormat.format(date);

    if (diffDays == 0) {
      return 'Hoy ${timeStr != '00:00' ? timeStr : ''}';
    } else if (diffDays == 1) {
      return 'Mañana ${timeStr != '00:00' ? timeStr : ''}';
    } else if (diffDays == -1) {
      return 'Ayer';
    } else if (diffDays < -1) {
      return 'Vencida hace ${-diffDays} días';
    } else if (diffDays <= 7) {
      final weekday = DateFormat('EEEE', 'es').format(date);
      return '${weekday[0].toUpperCase()}${weekday.substring(1)}';
    } else {
      return _shortDateFormat.format(date);
    }
  }

  static String formatFullDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime date) {
    return '${_dateFormat.format(date)} ${_timeFormat.format(date)}';
  }
}
