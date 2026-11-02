import 'package:flutter/material.dart';
import 'package:task_check/features/tasks/domain/task_priority.dart';

/// Reusable priority badge with icon and label
class PriorityBadge extends StatelessWidget {
  final TaskPriority priority;
  final bool showLabel;
  final double iconSize;
  final double fontSize;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
    this.iconSize = 12,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 8 : 4, vertical: 3),
      decoration: BoxDecoration(
        color: priority.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priority.icon, size: iconSize, color: priority.color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              priority.label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: priority.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
