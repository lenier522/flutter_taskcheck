import 'package:flutter/material.dart';

enum TaskPriority {
  low(0, 'Baja', Icons.keyboard_double_arrow_down, Color(0xFF64748B)),
  normal(1, 'Normal', Icons.remove, Color(0xFF3B82F6)),
  high(2, 'Alta', Icons.keyboard_double_arrow_up, Color(0xFFF59E0B)),
  urgent(3, 'Urgente', Icons.warning_amber_rounded, Color(0xFFEF4444));

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const TaskPriority(this.value, this.label, this.icon, this.color);

  static TaskPriority fromValue(int? val) {
    if (val == null) return TaskPriority.normal;
    return TaskPriority.values.firstWhere(
      (p) => p.value == val,
      orElse: () => TaskPriority.normal,
    );
  }
}
