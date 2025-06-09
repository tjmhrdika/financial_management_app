import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

class ExpenseList extends StatelessWidget {
  const ExpenseList({super.key});

  Stream<List<Map<String, dynamic>>> _expenseWithCategoryStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

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
          doc.id: ExpenseCategory.fromDoc(doc)
      };

      return expenseSnap.docs.map((doc) {
        final expense = Expense.fromDoc(doc);
        final category = categoryMap[expense.categoryId];
        return {
          'expense': expense,
          'category': category,
        };
      }).toList();
    });
  }

  void _showUpdateDialog(BuildContext context, Expense expense) {
    final _descriptionController = TextEditingController(text: expense.description);
    final _amountController = TextEditingController(text: expense.amount.toString());
    String? _selectedCategoryId = expense.categoryId;
    DateTime _selectedDate = expense.date;
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Update Expense'),
          content: FutureBuilder(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('expenseCategories')
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
                    .collection('expenses')
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _expenseWithCategoryStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        DateTime? lastDate;

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final Expense expense = item['expense'];
            final ExpenseCategory? category = item['category'];
            final showDate = lastDate == null ||
                lastDate!.day != expense.date.day ||
                lastDate!.month != expense.date.month ||
                lastDate!.year != expense.date.year;
            lastDate = expense.date;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDate)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ListTile(
                  leading: category != null
                      ? Image.network(category.iconUrl, width: 30, height: 30)
                      : const Icon(Icons.category),
                  title: Text(expense.description),
                  subtitle: category != null ? Text(category.name) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('-Rp${expense.amount}', style: const TextStyle(color: Colors.red)),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showUpdateDialog(context, expense),
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
                                  .doc(expense.id)
                                  .delete();
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}