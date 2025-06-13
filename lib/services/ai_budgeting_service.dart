import '../models/savings_goal.dart';
import '../services/openrouter_service.dart';
import '../services/savings_goal_service.dart';
import 'package:intl/intl.dart';

class AIBudgetingService {
  final OpenRouterService _openRouterService = OpenRouterService();
  final SavingsGoalService _savingsGoalService = SavingsGoalService();
  final dateFormatter = DateFormat('yyyy-MM-dd');
  final DateTime now = DateTime.now();
      
  Future<AIBudgetingResult> generateBudgetingPlan({
    required String userGoals,
    required double monthlyIncome,
    required double monthlyExpenses,
  }) async {
    final formattedDate = dateFormatter.format(now);

    try {
      if (userGoals.trim().isEmpty) {
        throw Exception('Please enter your financial goals');
      }
      if (monthlyIncome <= monthlyExpenses) {
        throw Exception('Income must be higher than expenses');
      }

      final aiResponse = await _openRouterService.generateBudgetingPlan(
        userPrompt: userGoals,
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
        today: formattedDate
      );

      if (aiResponse == null) {
        throw Exception('AI service failed. Please try again.');
      }

      final goals = _createGoalsFromAI(aiResponse);
      
      return AIBudgetingResult(
        goals: goals,
        summary: aiResponse['summary'] ?? 'AI created your savings plan',
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
      );
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> createSelectedGoalsAndReplaceAll(List<SavingsGoal> selectedGoals) async {
    try {
      final oldGoals = await _savingsGoalService.fetchSavingsGoals();
      for (final goal in oldGoals) {
        await _savingsGoalService.deleteSavingsGoal(goal.id);
      }
      
      for (final goal in selectedGoals) {
        await _savingsGoalService.addSavingsGoal(goal);
      }
    } catch (e) {
      throw Exception('Failed to create goals: $e');
    }
  }

  Future<int> getExistingGoalsCount() async {
    try {
      final goals = await _savingsGoalService.fetchSavingsGoals();
      return goals.length;
    } catch (e) {
      return 0;
    }
  }

  List<SavingsGoal> _createGoalsFromAI(Map<String, dynamic> aiResponse) {
    final goalsData = aiResponse['goals'] as List;
    List<SavingsGoal> goals = [];

    for (var goalData in goalsData) {
      try {
        final name = goalData['name'] as String;
        final target = (goalData['target'] as num).toDouble();
        final deadlineStr = goalData['deadline'] as String;
        
        DateTime deadline;
        try {
          deadline = DateTime.parse(deadlineStr);
        } catch (e) {
          deadline = DateTime.now().add(Duration(days: 365));
        }

        goals.add(SavingsGoal(
          id: '',
          name: name,
          targetAmount: target,
          currentAmount: 0.0,
          deadline: deadline,
          createdDate: DateTime.now(),
          isCompleted: false,
        ));
      } catch (e) {
        continue;
      }
    }

    return goals;
  }
}

class AIBudgetingResult {
  final List<SavingsGoal> goals;
  final String summary;
  final double monthlyIncome;
  final double monthlyExpenses;

  AIBudgetingResult({
    required this.goals,
    required this.summary,
    required this.monthlyIncome,
    required this.monthlyExpenses,
  });

  double get monthlySavingsPotential => monthlyIncome - monthlyExpenses;
  double get savingsRate => monthlyIncome > 0 ? (monthlySavingsPotential / monthlyIncome) * 100 : 0;
  bool get hasPositiveSavings => monthlySavingsPotential > 0;
}