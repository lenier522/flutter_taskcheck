class Subtask {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int sortOrder;

  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.sortOrder = 0,
  });

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    int? sortOrder,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subtask &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          taskId == other.taskId &&
          title == other.title &&
          isCompleted == other.isCompleted &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      id.hashCode ^
      taskId.hashCode ^
      title.hashCode ^
      isCompleted.hashCode ^
      sortOrder.hashCode;
}
