import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:financial_management_app/widgets/expense_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:financial_management_app/services/income_allocation_service.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/savings_goal.dart';
import '../services/savings_goal_service.dart'; 
import 'category_crud_dialog.dart';
import 'package:financial_management_app/utils/currency_formatter.dart';

class AddExpenseForm extends StatefulWidget {
  const AddExpenseForm({super.key});

  @override
  State<AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<AddExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final SavingsGoalService _savingsGoalService = SavingsGoalService(); 
  final IncomeAllocationService _incomeAllocationService = IncomeAllocationService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  List<ExpenseCategory> _categories = [];
  bool _isExpense = true;

  List<SavingsGoal> _savingsGoals = [];
  Map<String, double> _goalAllocations = {};

  

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSavingsGoals();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collectionName = _isExpense ? 'expenseCategories' : 'incomeCategories';
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(collectionName)
        .get();

    setState(() {
      _categories = snapshot.docs.map((doc) => ExpenseCategory.fromDoc(doc)).toList();
      _selectedCategoryId = null;
    });
  }

  Future<void> _loadSavingsGoals() async {
    try {
      final goals = await _savingsGoalService.fetchActiveSavingsGoals();
      setState(() {
        _savingsGoals = goals;
        _goalAllocations = {};
      });
    } catch (e) {
      setState(() {
        _savingsGoals = [];
        _goalAllocations = {};
      });
    }
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_isExpense && _goalAllocations.isNotEmpty) {
      final totalIncome = double.tryParse(_amountController.text) ?? 0;
      final totalAllocated = _goalAllocations.values.fold(0.0, (sum, amount) => sum + amount);
      
      if (totalAllocated > totalIncome) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total allocations cannot exceed income amount'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      final amount = int.parse(_amountController.text);

      final data = Expense(
        id: '',
        date: _selectedDate,
        description: _descriptionController.text,
        amount: amount,
        categoryId: _selectedCategoryId!,
      );

      final collection = _isExpense ? 'expenses' : 'incomes';
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collection)
          .add(data.toMap());

      if (!_isExpense && _goalAllocations.isNotEmpty) {
        await _savingsGoalService.updateMultipleGoalAllocations(_goalAllocations);
        await _incomeAllocationService.saveAllocations(docRef.id, _goalAllocations);
      }

      _descriptionController.clear();
      _amountController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _selectedCategoryId = null;
        _goalAllocations = {};
      });

      if (!_isExpense && _goalAllocations.isNotEmpty) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Income added and allocated to savings goals!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      String filterToPass = _isExpense ? 'Expenses' : 'Income';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseList(initialFilter: filterToPass)
        ),
        (route) => false, 
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._categories.map((category) {
          final isSelected = _selectedCategoryId == category.id;
          return ChoiceChip(
            label: Text(category.name),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedCategoryId = category.id;
              });
            },
            selectedColor: _isExpense ? Colors.red[200] : Colors.green[200],
            backgroundColor: Colors.grey[200],
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }).toList(),
        ActionChip(
          avatar: Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text(''),
          backgroundColor: _isExpense ? Colors.red : Colors.green,
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (ctx) => CategoryCrudDialog(
                onUpdate: _loadCategories,
                isExpense: _isExpense
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSavingsAllocationSection() {
    if (_isExpense) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.savings, color: Colors.green[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Allocate to Savings Goals (Optional)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Income: ${_amountController.text.isEmpty ? "Rp. 0" : CurrencyFormatter.format(int.tryParse(_amountController.text) ?? 0)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              ..._savingsGoals.map((goal) => _buildGoalAllocationRow(goal)).toList(),
              
              if (_savingsGoals.isEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'No active savings goals. Create one first!',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, 
                        '/home', 
                        (route) => false,
                        arguments: {'initialTab': 'budgeting'} 
                      ),
                      child: const Text('Create Goal'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

 Widget _buildGoalAllocationRow(SavingsGoal goal) {
    final controller = TextEditingController(
      text: _goalAllocations[goal.id]?.toString() ?? '',
    );
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.savings, color: Colors.blue, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${goal.progressPercentage.toStringAsFixed(1)}% complete • ${goal.daysRemaining} days left',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: 'Rp. ',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  onChanged: (value) {
                    final amount = double.tryParse(value) ?? 0;
                    _goalAllocations[goal.id] = amount;
                    
                    final totalIncome = double.tryParse(_amountController.text) ?? 0;
                    final totalAllocated = _goalAllocations.values.fold(0.0, (sum, amount) => sum + amount);
                    
                    if (totalAllocated > totalIncome && totalIncome > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Total allocations exceed income!',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                    
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final totalIncome = double.tryParse(_amountController.text) ?? 0;
                  final currentAllocation = _goalAllocations[goal.id] ?? 0;
                  final otherAllocations = _goalAllocations.values
                      .where((allocation) => allocation != currentAllocation)
                      .fold(0.0, (sum, allocation) => sum + allocation);
                  final remaining = totalIncome - otherAllocations;
                  
                  if (remaining > 0) {
                    controller.text = remaining.toString();
                    _goalAllocations[goal.id] = remaining;
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final label = _isExpense ? "Category" : "Category";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Expenses'),
                  selected: _isExpense,
                  selectedColor: Colors.red[100],
                  onSelected: (_) {
                    setState(() {
                      _isExpense = true;
                      _goalAllocations = {};  
                    });
                    _loadCategories();
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: !_isExpense,
                  selectedColor: Colors.green[100],
                  onSelected: (_) {
                    setState(() {
                      _isExpense = false;
                      _goalAllocations = {}; 
                    });
                    _loadCategories();
                    _loadSavingsGoals(); 
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text("Date", style: Theme.of(context).textTheme.labelLarge),
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (val) {
                final parsed = int.tryParse(val ?? '');
                if (parsed == null || parsed < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            
            _buildSavingsAllocationSection(),
            
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    _descriptionController.clear();
                    _amountController.clear();
                    setState(() {
                      _selectedCategoryId = null;
                      _goalAllocations = {};
                    });
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isExpense ? Colors.red : Colors.green,
                  ),
                  onPressed: () async{
                    if (_descriptionController.text.isEmpty ||
                        _amountController.text.isEmpty ||
                        _selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please fill in all fields before submitting.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    await _submit();
                  },
                  
                  child: Text(_isExpense ? "Add Expense" : "Add Income",
                  style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}