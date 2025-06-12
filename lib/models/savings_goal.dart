import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final DateTime createdDate;
  final bool isCompleted;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.createdDate,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': Timestamp.fromDate(deadline),
      'createdDate': Timestamp.fromDate(createdDate),
      'isCompleted': isCompleted,
    };
  }

  factory SavingsGoal.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavingsGoal(
      id: doc.id,
      name: data['name'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0.0).toDouble(),
      currentAmount: (data['currentAmount'] ?? 0.0).toDouble(),
      deadline: (data['deadline'] as Timestamp).toDate(),
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  double get progressPercentage {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount * 100).clamp(0, 100);
  }

  bool get isOverdue {
    return !isCompleted && DateTime.now().isAfter(deadline);
  }

  int get daysRemaining {
    if (isCompleted) return 0;
    final difference = deadline.difference(DateTime.now()).inDays;
    return difference < 0 ? 0 : difference;
  }
}