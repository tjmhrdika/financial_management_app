import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

class ExpenseList extends StatefulWidget {
  final String initialFilter;
  const ExpenseList({super.key, required this.initialFilter});

  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  late String selectedFilter = widget.initialFilter;

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
    final _descriptionController = TextEditingController(text: expense.description);
    final _amountController = TextEditingController(text: expense.amount.toString());
    String? _selectedCategoryId = expense.categoryId;
    DateTime _selectedDate = expense.date;
    final user = FirebaseAuth.instance.currentUser;
    final type = isIncome ? 'Income' : 'Expense';
    final collection = isIncome ? 'incomes' : 'expenses';
    final collectionCategories = isIncome ? 'incomeCategories' : 'expenseCategories';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Update $type'),
          content: FutureBuilder(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection(collectionCategories)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              final categories = snapshot.data!.docs
                  .map((doc) => ExpenseCategory.fromDoc(doc))
                  .toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (Rp)'),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      final n = int.tryParse(val);
                      return n == null || n < 0 ? 'Must be a non-negative number' : null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    items: categories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  Row(
                    children: [
                      const Text('Date: '),
                      TextButton(
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
                        child: Text('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final amount = int.tryParse(_amountController.text);
                if (_descriptionController.text.isEmpty ||
                    amount == null || amount < 0 ||
                    _selectedCategoryId == null) return;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection(collection)
                    .doc(expense.id)
                    .update({
                  'description': _descriptionController.text,
                  'amount': amount,
                  'categoryId': _selectedCategoryId,
                  'date': Timestamp.fromDate(_selectedDate),
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
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
                                  '${amountPrefix}Rp${transaction.amount.toString()}',
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