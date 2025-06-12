import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:financial_management_app/widgets/expense_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import 'category_crud_dialog.dart';

class AddExpenseForm extends StatefulWidget {
  const AddExpenseForm({super.key});

  @override
  State<AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<AddExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  List<ExpenseCategory> _categories = [];
  bool _isExpense = true;


  @override
  void initState() {
    super.initState();
    _loadCategories();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = Expense(
      id: '',
      date: _selectedDate,
      description: _descriptionController.text,
      amount: int.parse(_amountController.text),
      categoryId: _selectedCategoryId!,
    );

    final collection = _isExpense ? 'expenses' : 'incomes';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(collection)
        .add(data.toMap());

    _descriptionController.clear();
    _amountController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCategoryId = null;
    });
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


  @override
  Widget build(BuildContext context) {
    final label = _isExpense ? "Category" : "Savings";

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
                    });
                    _loadCategories();

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
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    _descriptionController.clear();
                    _amountController.clear();
                    setState(() => _selectedCategoryId = null);
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

                    String filterToPass = _isExpense ? 'Expenses' : 'Income';
                    
                   Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExpenseList(initialFilter: filterToPass)
                      ),
                      (route) => false, 
                    );
                  },
                  child: Text("Add"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
