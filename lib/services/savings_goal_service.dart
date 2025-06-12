import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/savings_goal.dart';

class SavingsGoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _getSavingsGoalsCollection() {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savingsGoals');
  }

  Future<List<SavingsGoal>> fetchSavingsGoals() async {
    final collection = _getSavingsGoalsCollection();
    if (collection == null) return [];

    try {
      final snapshot = await collection
          .orderBy('createdDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SavingsGoal.fromDoc(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch savings goals: $e');
    }
  }

  Future<List<SavingsGoal>> fetchActiveSavingsGoals() async {
    final collection = _getSavingsGoalsCollection();
    if (collection == null) return [];

    try {
      final snapshot = await collection
          .where('isCompleted', isEqualTo: false)
          .get();

      return snapshot.docs
          .map((doc) => SavingsGoal.fromDoc(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active savings goals: $e');
    }
  }

  Future<void> addSavingsGoal(SavingsGoal goal) async {
    final collection = _getSavingsGoalsCollection();
    if (collection == null) throw Exception('User not authenticated');

    try {
      await collection.add(goal.toMap());
    } catch (e) {
      throw Exception('Failed to add savings goal: $e');
    }
  }

  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    final collection = _getSavingsGoalsCollection();
    if (collection == null) throw Exception('User not authenticated');

    try {
      await collection.doc(goal.id).update(goal.toMap());
    } catch (e) {
      throw Exception('Failed to update savings goal: $e');
    }
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    final collection = _getSavingsGoalsCollection();
    if (collection == null) throw Exception('User not authenticated');

    try {
      await collection.doc(goalId).delete();
    } catch (e) {
      throw Exception('Failed to delete savings goal: $e');
    }
  }

  Future<void> updateGoalAllocation(String goalId, double amount) async {
    final collection = _getSavingsGoalsCollection();
    if (collection == null) throw Exception('User not authenticated');

    try {
      final doc = await collection.doc(goalId).get();
      if (!doc.exists) throw Exception('Savings goal not found');

      final goal = SavingsGoal.fromDoc(doc);
      final newCurrentAmount = goal.currentAmount + amount;
      final isNowCompleted = newCurrentAmount >= goal.targetAmount;

      await collection.doc(goalId).update({
        'currentAmount': newCurrentAmount,
        'isCompleted': isNowCompleted,
      });
    } catch (e) {
      throw Exception('Failed to update goal allocation: $e');
    }
  }

  Future<void> updateMultipleGoalAllocations(Map<String, double> allocations) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();

      for (final entry in allocations.entries) {
        if (entry.value > 0) {
          final goalId = entry.key;
          final amount = entry.value;

          final goalRef = _firestore
              .collection('users')
              .doc(user.uid)
              .collection('savingsGoals')
              .doc(goalId);

          final goalDoc = await goalRef.get();
          if (!goalDoc.exists) continue;

          final goal = SavingsGoal.fromDoc(goalDoc);
          final newCurrentAmount = goal.currentAmount + amount;
          final isNowCompleted = newCurrentAmount >= goal.targetAmount;

          batch.update(goalRef, {
            'currentAmount': newCurrentAmount,
            'isCompleted': isNowCompleted,
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update goal allocations: $e');
    }
  }

  Stream<List<SavingsGoal>> getSavingsGoalsStream() {
    final collection = _getSavingsGoalsCollection();
    if (collection == null) return const Stream.empty();

    return collection
        .orderBy('createdDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SavingsGoal.fromDoc(doc))
            .toList());
  }

  Future<Map<String, dynamic>> getSavingsGoalsSummary() async {
    final goals = await fetchSavingsGoals();
    
    final totalGoals = goals.length;
    final completedGoals = goals.where((g) => g.isCompleted).length;
    final activeGoals = totalGoals - completedGoals;
    final totalTargetAmount = goals.fold(0.0, (sum, goal) => sum + goal.targetAmount);
    final totalCurrentAmount = goals.fold(0.0, (sum, goal) => sum + goal.currentAmount);
    final overallProgress = totalTargetAmount > 0 ? (totalCurrentAmount / totalTargetAmount * 100) : 0.0;

    return {
      'totalGoals': totalGoals,
      'completedGoals': completedGoals,
      'activeGoals': activeGoals,
      'totalTargetAmount': totalTargetAmount,
      'totalCurrentAmount': totalCurrentAmount,
      'overallProgress': overallProgress,
    };
  }

  bool validateSavingsGoal({
    required String name,
    required double targetAmount,
    required double currentAmount,
    required DateTime deadline,
  }) {
    if (name.trim().isEmpty) return false;
    if (targetAmount <= 0) return false;
    if (currentAmount < 0) return false;
    if (deadline.isBefore(DateTime.now())) return false;
    return true;
  }
}