import 'package:flutter/material.dart';
import '../models/savings_goal.dart';
import '../services/ai_budgeting_service.dart';
import 'savings_goal_screen.dart';
import 'package:financial_management_app/screens/ai_result_screen.dart';

class AIBudgetingScreen extends StatefulWidget {
  const AIBudgetingScreen({super.key});

  @override
  State<AIBudgetingScreen> createState() => _AIBudgetingScreenState();
}

class _AIBudgetingScreenState extends State<AIBudgetingScreen> {
  final AIBudgetingService _aiBudgetingService = AIBudgetingService();
  final _formKey = GlobalKey<FormState>();
  final _goalsController = TextEditingController();
  final _incomeController = TextEditingController();
  final _expensesController = TextEditingController();

  bool _isLoading = false;
  int _existingGoalsCount = 0;
  AIBudgetingResult? _aiResult;
  List<bool> _selectedGoals = [];

  @override
  void initState() {
    super.initState();
    _loadExistingGoalsCount();
  }

  @override
  void dispose() {
    _goalsController.dispose();
    _incomeController.dispose();
    _expensesController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingGoalsCount() async {
    try {
      final count = await _aiBudgetingService.getExistingGoalsCount();
      setState(() {
        _existingGoalsCount = count;
      });
    } catch (e) {
      setState(() {
        _existingGoalsCount = 0;
      });
    }
  }

  Future<void> _generatePlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final monthlyIncome = double.parse(_incomeController.text);
      final monthlyExpenses = double.parse(_expensesController.text);

      final result = await _aiBudgetingService.generateBudgetingPlan(
        userGoals: _goalsController.text,
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
      );

      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AIResultsScreen(
            aiResult: result,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _createSelectedGoals() async {
    if (_aiResult == null) return;

    final selectedGoalsList = <SavingsGoal>[];
    for (int i = 0; i < _selectedGoals.length; i++) {
      if (_selectedGoals[i]) {
        selectedGoalsList.add(_aiResult!.goals[i]);
      }
    }

    if (selectedGoalsList.isEmpty) {
      _showErrorSnackBar('Please select at least one goal to create');
      return;
    }

    // Show confirmation dialog if there are existing goals
    if (_existingGoalsCount > 0) {
      final confirmed = await _showReplacementConfirmationDialog();
      if (!confirmed) return;
    }

    setState(() => _isLoading = true);

    try {
      await _aiBudgetingService.createSelectedGoalsAndReplaceAll(selectedGoalsList);
      
      _showSuccessSnackBar('Successfully replaced all goals with ${selectedGoalsList.length} new AI-generated goals!');
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SavingsGoalsScreen(),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to create goals: $e');
    }
  }

  Future<bool> _showReplacementConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('Replace Existing Goals?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You currently have $_existingGoalsCount savings goal(s).'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Text(
                '⚠️ Creating an AI budget plan will DELETE all your existing goals and replace them with new AI-generated ones.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            const Text('This action cannot be undone. Do you want to continue?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Replace All Goals'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.psychology, color: Colors.purple[600]),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI Financial Planning',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text('What are your financial goals?', 
                       style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(
                minHeight: 120, // Minimum height for text area
                maxHeight: 200, // Maximum height to prevent overflow
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextFormField(
                controller: _goalsController,
                maxLines: null, // Allow unlimited lines within constraints
                textAlignVertical: TextAlignVertical.top, // Align text to top
                decoration: const InputDecoration(
                  hintText: 'e.g., I want to achieve financial freedom in 5 years, buy a house, save for retirement, and have an emergency fund...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'Please describe your financial goals' : null,
              ),
            ),
            const SizedBox(height: 16),

            const Text('Monthly Income & Expenses', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _incomeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Income',
                        prefixText: 'Rp. ',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value ?? '');
                        if (amount == null || amount <= 0) return 'Enter valid income';
                        return null;
                      },
                      onChanged: (value) {
                        // Show real-time savings calculation
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _expensesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Expenses',
                        prefixText: 'Rp. ',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value ?? '');
                        if (amount == null || amount < 0) return 'Enter valid expenses';
                        final income = double.tryParse(_incomeController.text);
                        if (income != null && amount >= income) return 'Expenses too high';
                        return null;
                      },
                      onChanged: (value) {
                        // Show real-time savings calculation
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generatePlan,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.psychology, color: Colors.white),
                label: Text(_isLoading ? 'Generating Plan...' : 'Generate AI Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildAIResults() {
    if (_aiResult == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple[100]!, Colors.blue[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.purple[600]),
                  const SizedBox(width: 8),
                  const Text('AI Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Text(_aiResult!.summary, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Monthly Savings', 'Rp. ${_aiResult!.monthlySavingsPotential.toStringAsFixed(0)}', Colors.green),
                  _buildSummaryItem('Savings Rate', '${_aiResult!.savingsRate.toStringAsFixed(1)}%', Colors.blue),
                  _buildSummaryItem('Goals Created', '${_aiResult!.goals.length}', Colors.purple),
                ],
              ),
            ],
          ),
        ),

        // Goals List
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Suggested Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedGoals = List.filled(_selectedGoals.length, !_selectedGoals.every((selected) => selected));
                    }),
                    child: Text(_selectedGoals.every((selected) => selected) ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),
              
              // Warning about existing goals
              if (_existingGoalsCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have $_existingGoalsCount existing goal(s). Creating this plan will replace all current goals.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 8),
              ..._aiResult!.goals.asMap().entries.map((entry) {
                final index = entry.key;
                final goal = entry.value;
                return _buildGoalCard(goal, index);
              }).toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createSelectedGoals,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.savings, color: Colors.white),
                  label: Text(_isLoading 
                      ? 'Creating Goals...' 
                      : _existingGoalsCount > 0 
                          ? 'Replace All Goals with Selected'
                          : 'Create Selected Goals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _existingGoalsCount > 0 ? Colors.orange[600] : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildGoalCard(SavingsGoal goal, int index) {
    final isSelected = _selectedGoals[index];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) => setState(() => _selectedGoals[index] = value ?? false),
        title: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: Rp. ${goal.targetAmount.toStringAsFixed(0)}'),
            Text('Deadline: ${goal.deadline.day}/${goal.deadline.month}/${goal.deadline.year}'),
            Text('${goal.daysRemaining} days to achieve', 
                 style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('AI Financial Planning', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(), // Better scroll physics
          padding: const EdgeInsets.only(bottom: 32), // Add bottom padding
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildInputForm(),
              _buildAIResults(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}