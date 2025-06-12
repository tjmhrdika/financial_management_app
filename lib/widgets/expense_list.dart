import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/savings_goal.dart';
import '../services/savings_goal_service.dart';
import '../services/income_allocation_service.dart';
import '../utils/currency_formatter.dart';

class ExpenseList extends StatefulWidget {
  final String initialFilter;
  const ExpenseList({super.key, required this.initialFilter});

  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  late String selectedFilter = widget.initialFilter;

  final savingsService = SavingsGoalService();
  final allocationService = IncomeAllocationService();

  Stream<List<Map<String, dynamic>>> _transactionStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    if (selectedFilter == 'All') {
      return _getAllTransactionsStream(user);
    } else if (selectedFilter == 'Expenses') {
      return _getExpensesStream(user);
    } else {
      return _getIncomeStream(user);
    }
  }

  Stream<List<Map<String, dynamic>>> _getAllTransactionsStream(User user) {
    final expensesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .orderBy('date', descending: true);
        
    final incomeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('incomes')
        .orderBy('date', descending: true);

    return expensesRef.snapshots().asyncMap((expenseSnap) async {
      final incomeSnap = await incomeRef.get();
      
      final expenseCategoriesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenseCategories')
          .get();
          
      final incomeCategoriesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('incomeCategories')
          .get();

      final expenseCategoryMap = {
        for (var doc in expenseCategoriesSnap.docs)
          doc.id: ExpenseCategory.fromDoc(doc),
      };
      
      final incomeCategoryMap = {
        for (var doc in incomeCategoriesSnap.docs)
          doc.id: ExpenseCategory.fromDoc(doc),
      };

      List<Map<String, dynamic>> allTransactions = [];

      allTransactions.addAll(expenseSnap.docs.map((doc) {
        final expense = Expense.fromDoc(doc);
        final category = expenseCategoryMap[expense.categoryId];
        return {
          'expense': expense,
          'category': category,
          'type': 'expense',
        };
      }));

      allTransactions.addAll(incomeSnap.docs.map((doc) {
        final income = Expense.fromDoc(doc);
        final category = incomeCategoryMap[income.categoryId];
        return {
          'expense': income,
          'category': category,
          'type': 'income',
        };
      }));

      allTransactions.sort((a, b) => 
          (b['expense'] as Expense).date.compareTo((a['expense'] as Expense).date));

      return allTransactions;
    });
  }

  Stream<List<Map<String, dynamic>>> _getExpensesStream(User user) {
    final expensesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .orderBy('date', descending: true);

    final categoriesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenseCategories');

    return expensesRef.snapshots().asyncMap((expenseSnap) async {
      final categorySnap = await categoriesRef.get();
      final categoryMap = {
        for (var doc in categorySnap.docs)
          doc.id: ExpenseCategory.fromDoc(doc),
      };

      return expenseSnap.docs.map((doc) {
        final expense = Expense.fromDoc(doc);
        final category = categoryMap[expense.categoryId];
        return {
          'expense': expense,
          'category': category,
          'type': 'expense',
        };
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> _getIncomeStream(User user) {
    final incomeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('incomes')
        .orderBy('date', descending: true);

    final categoriesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('incomeCategories');

    return incomeRef.snapshots().asyncMap((incomeSnap) async {
      final categorySnap = await categoriesRef.get();
      final categoryMap = {
        for (var doc in categorySnap.docs)
          doc.id: ExpenseCategory.fromDoc(doc),
      };

      return incomeSnap.docs.map((doc) {
        final income = Expense.fromDoc(doc);
        final category = categoryMap[income.categoryId];
        return {
          'expense': income,
          'category': category,
          'type': 'income',
        };
      }).toList();
    });
  }

  void _showUpdateDialog(BuildContext context, Expense expense, bool isIncome) {
    final descController = TextEditingController(text: expense.description);
    final amountController = TextEditingController(text: CurrencyFormatter.formatNumber(expense.amount));
    String? selectedCategoryId = expense.categoryId;
    DateTime selectedDate = expense.date;
    final user = FirebaseAuth.instance.currentUser;

    List<SavingsGoal> savingsGoals = [];
    Map<String, double> goalAllocations = {};
    bool dataLoaded = false;

    Future<Map<String, dynamic>> loadDialogData(User user, bool isIncome, String expenseId) async {
      final collectionName = isIncome ? 'incomeCategories' : 'expenseCategories';
      final categoryDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .get();
      
      final categories = categoryDocs.docs.map((doc) => ExpenseCategory.fromDoc(doc)).toList();

      Map<String, dynamic> result = {'categories': categories};

      if (isIncome) {
        try {
          final goals = await savingsService.fetchActiveSavingsGoals();
          final allocations = await allocationService.getIncomeAllocations(expenseId);
          
          result['savingsGoals'] = goals;
          result['allocations'] = allocations;
        } catch (e) {
          result['savingsGoals'] = [];
          result['allocations'] = {};
        }
      }

      return result;
    }

    Future<void> saveTransaction(
      User user,
      Expense expense,
      bool isIncome,
      TextEditingController descController,
      TextEditingController amountController,
      String? selectedCategoryId,
      DateTime selectedDate,
      Map<String, double> goalAllocations,
    ) async {
      final amount = int.tryParse(amountController.text);
      if (descController.text.isEmpty || amount == null || amount < 0 || selectedCategoryId == null) {
        return;
      }

      if (isIncome && goalAllocations.isNotEmpty) {
        final totalAllocated = goalAllocations.values.fold(0.0, (sum, amount) => sum + amount);
        if (totalAllocated > amount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Allocations exceed income amount'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      try {
        final collection = isIncome ? 'incomes' : 'expenses';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(collection)
            .doc(expense.id)
            .update({
          'description': descController.text,
          'amount': amount,
          'categoryId': selectedCategoryId,
          'date': Timestamp.fromDate(selectedDate),
        });

        if (isIncome) {
          if (goalAllocations.isNotEmpty) {
            await savingsService.updateMultipleGoalAllocations(goalAllocations);
            await allocationService.updateAllocations(expense.id, goalAllocations);
          } else {
            await allocationService.deleteIncomeAllocations(expense.id);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isIncome ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isIncome ? 'Edit Income' : 'Edit Expense',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable content
                Expanded(
                  child: FutureBuilder(
                    future: loadDialogData(user!, isIncome, expense.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      
                      final data = snapshot.data as Map<String, dynamic>;
                      final categories = data['categories'];
                      
                      if (isIncome && !dataLoaded) {
                        savingsGoals = data['savingsGoals'] ?? [];
                        goalAllocations = data['allocations'] ?? {};
                        dataLoaded = true;
                      }
                      
                      return SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic fields
                            TextField(
                              controller: descController,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Amount (Rp)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                final cleanValue = value.replaceAll(',', '');
                                final amount = int.tryParse(cleanValue);
                                if (amount != null && amount > 0) {
                                  final formatted = CurrencyFormatter.formatNumber(amount);
                                  if (amountController.text != formatted) {
                                    amountController.text = formatted;
                                    amountController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: amountController.text.length),
                                    );
                                  }
                                }
                              },
                            ),
                            SizedBox(height: 16),
                            
                            DropdownButtonFormField<String>(
                              value: selectedCategoryId,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: categories.map<DropdownMenuItem<String>>((category) {
                                return DropdownMenuItem<String>(
                                  value: category.id,
                                  child: Text(category.name),
                                );
                              }).toList(),
                              onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                            ),
                            SizedBox(height: 16),
                            
                            // Date picker
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today),
                                    SizedBox(width: 12),
                                    Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                                  ],
                                ),
                              ),
                            ),
                            
                            if (isIncome) ...[
                              SizedBox(height: 24),
                              Text(
                                'Savings Allocations',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 16),
                              
                              if (savingsGoals.isEmpty)
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('No savings goals available'),
                                )
                              else ...[
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    border: Border.all(color: Colors.green[200]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Income: ${CurrencyFormatter.format(int.tryParse((amountController.text)))}'),
                                      Text('Allocated: ${CurrencyFormatter.format(goalAllocations.values.fold(0.0, (sum, amount) => sum + amount).round())}'),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                                
                                ...savingsGoals.map((goal) {
                                  final controller = TextEditingController(
                                    text: goalAllocations[goal.id]?.toString() ?? '',
                                  );
                                  
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          goal.name,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: controller,
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  prefixText: 'Rp. ',
                                                  border: OutlineInputBorder(),
                                                ),
                                                onChanged: (value) {
                                                  final amount = double.tryParse(value) ?? 0;
                                                  goalAllocations[goal.id] = amount;
                                                  
                                                  final totalIncome = double.tryParse(amountController.text) ?? 0;
                                                  final totalAllocated = goalAllocations.values.fold(0.0, (sum, amount) => sum + amount);
                                                  
                                                  if (totalAllocated > totalIncome && totalIncome > 0) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Total allocation exceeds income!'),
                                                        backgroundColor: Colors.orange,
                                                        duration: Duration(seconds: 1),
                                                      ),
                                                    );
                                                  }
                                                  
                                                  setDialogState(() {});
                                                },
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            ElevatedButton(
                                              onPressed: () {
                                                final totalIncome = double.tryParse(amountController.text) ?? 0;
                                                final currentAmount = goalAllocations[goal.id] ?? 0;
                                                final otherAllocations = goalAllocations.values
                                                    .where((allocation) => allocation != currentAmount)
                                                    .fold(0.0, (sum, allocation) => sum + allocation);
                                                final remaining = totalIncome - otherAllocations;
                                                
                                                if (remaining > 0) {
                                                  controller.text = remaining.toString();
                                                  goalAllocations[goal.id] = remaining;
                                                  setDialogState(() {});
                                                }
                                              },
                                              child: Text('All'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                              
                              SizedBox(height: 20),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await saveTransaction(
                              user,
                              expense,
                              isIncome,
                              descController,
                              amountController,
                              selectedCategoryId,
                              selectedDate,
                              goalAllocations,
                            );
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isIncome ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context, 
            '/home', 
            (route) => false,
            arguments: {'initialTab': 'expenses'} 
          )
        ),
        title: const Text('Last Transactions'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildChip('All'),
                const SizedBox(width: 8),
                _buildChip('Expenses'),
                const SizedBox(width: 8),
                _buildChip('Income'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _transactionStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!;
                DateTime? lastDate;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final Expense transaction = item['expense'];
                    final ExpenseCategory? category = item['category'];
                    final String type = item['type'] ?? 'expense';
                    
                    final showDate = lastDate == null ||
                        lastDate!.day != transaction.date.day ||
                        lastDate!.month != transaction.date.month ||
                        lastDate!.year != transaction.date.year;
                    lastDate = transaction.date;

                    final isIncome = type == 'income';
                    final amountColor = isIncome ? Colors.green : Colors.red;
                    final amountPrefix = isIncome ? '+' : '-';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              '${transaction.date.day.toString().padLeft(2, '0')} '
                              '${_monthName(transaction.date.month)} '
                              '${transaction.date.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: category != null
                                ? Image.network(
                                    category.iconUrl,
                                    width: 40, 
                                    height: 40,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.category),
                                  )
                                : const Icon(Icons.category),
                            title: Text(transaction.description),
                            subtitle: Text(category?.name ?? 'No Category'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Rp${transaction.amount.toString()}',
                                  style: TextStyle(
                                    color: amountColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showUpdateDialog(context, transaction, isIncome),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    final confirm = await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Confirm Deletion'),
                                        content: const Text('Are you sure you want to delete this expense?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final user = FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .collection('expenses')
                                            .doc(transaction.id)
                                            .delete();
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = selectedFilter == label;
    Color? backgroundColor;
    
    if (isSelected) {
      if (label == 'Expenses') {
        backgroundColor = Colors.red[100];
      } else if (label == 'Income') {
        backgroundColor = Colors.green[100];
      } else {
        backgroundColor = Colors.grey[300];
      }
    } else {
      backgroundColor = Colors.grey[100];
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = label;
        });
      },
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}