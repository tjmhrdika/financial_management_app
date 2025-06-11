import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/expense_category.dart';

class CategoryCrudDialog extends StatefulWidget {
  final VoidCallback onUpdate;
  final bool isExpense; 
  
  const CategoryCrudDialog({
    super.key, 
    required this.onUpdate,
    required this.isExpense, 
  });

  @override
  State<CategoryCrudDialog> createState() => _CategoryCrudDialogState();
}

class _CategoryCrudDialogState extends State<CategoryCrudDialog> {
  late bool _isExpenseTab;
  List<ExpenseCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _isExpenseTab = widget.isExpense;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    String collection = _isExpenseTab ? 'expenseCategories' : 'incomeCategories';
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(collection)
        .get();
        
    setState(() {
      _categories = snapshot.docs.map((doc) => ExpenseCategory.fromDoc(doc)).toList();
    });
  }

  Future<void> _showAddEditForm({ExpenseCategory? category}) async {
    final nameController = TextEditingController(text: category?.name);
    final iconUrlController = TextEditingController(text: category?.iconUrl);
    final user = FirebaseAuth.instance.currentUser;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isExpenseTab = true;
                      Navigator.pop(ctx);
                      _loadCategories();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isExpenseTab ? Colors.red[300] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Expenses',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isExpenseTab = false;
                      Navigator.pop(ctx);
                      _loadCategories();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isExpenseTab ? Colors.green[200] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Income',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: iconUrlController,
              decoration: const InputDecoration(
                labelText: 'Category Icon',
                border: UnderlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final icon = iconUrlController.text.trim();
              if (name.isEmpty || icon.isEmpty || user == null) return;
              
              String collection = _isExpenseTab ? 'expenseCategories' : 'incomeCategories';
              final col = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection(collection);
                  
              if (category == null) {
                await col.add({
                  'name': name,
                  'iconUrl': icon,
                });
              } else {
                await col.doc(category.id).update({
                  'name': name,
                  'iconUrl': icon,
                });
              }
              
              Navigator.pop(ctx);
              await _loadCategories();
              widget.onUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(category == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(ExpenseCategory category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      String collection = _isExpenseTab ? 'expenseCategories' : 'incomeCategories';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collection)
          .doc(category.id)
          .delete();
          
      await _loadCategories();
      widget.onUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpenseTab = true;
                      });
                      _loadCategories();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isExpenseTab ? Colors.red[300] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Expenses',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpenseTab = false;
                      });
                      _loadCategories();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isExpenseTab ? Colors.green[200] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Income',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              height: 200,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return ListTile(
                    leading: Image.network(
                      cat.iconUrl, 
                      width: 30, 
                      height: 30,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.category, size: 30),
                    ),
                    title: Text(cat.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAddEditForm(category: cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _deleteCategory(cat),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _showAddEditForm(),
          child: const Text('Add Category'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}