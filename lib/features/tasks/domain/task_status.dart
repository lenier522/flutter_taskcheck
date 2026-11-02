import 'package:flutter/material.dart';

enum TaskStatus {
  pending(0, 'Pendiente', Icons.radio_button_unchecked, Color(0xFF64748B)),
  inProgress(1, 'En progreso', Icons.hourglass_top_rounded, Color(0xFF3B82F6)),
  completed(2, 'Completada', Icons.check_circle_rounded, Color(0xFF10B981));

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const TaskStatus(this.value, this.label, this.icon, this.color);

  static TaskStatus fromValue(int? val) {
    if (val == null) return TaskStatus.pending;
    return TaskStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => TaskStatus.pending,
    );
  }
}
