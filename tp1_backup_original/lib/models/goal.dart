class Goal {
  final String id;
  final String userId;
  final String type; // workoutsPerWeek, calories, protein, water, weight
  final double target;
  final double current;
  final String unit;
  final DateTime createdAt;
  final DateTime? deadline;

  Goal({
    required this.id,
    required this.userId,
    required this.type,
    required this.target,
    this.current = 0,
    required this.unit,
    required this.createdAt,
    this.deadline,
  });

  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);
  double get remaining => (target - current).clamp(0.0, double.infinity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'target': target,
      'current': current,
      'unit': unit,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      target: map['target']?.toDouble() ?? 0,
      current: map['current']?.toDouble() ?? 0,
      unit: map['unit'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
    );
  }
}
