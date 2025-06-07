import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/expense_category.dart';

class CategoryCrudDialog extends StatefulWidget {
  final VoidCallback onUpdate;
  const CategoryCrudDialog({super.key, required this.onUpdate});

  @override
  State<CategoryCrudDialog> createState() => _CategoryCrudDialogState();
}

class _CategoryCrudDialogState extends State<CategoryCrudDialog> {
  List<ExpenseCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenseCategories')
        .get();
    setState(() {
      _categories = snapshot.docs.map((doc) => ExpenseCategory.fromDoc(doc)).toList();
    });
  }

  Future<void> _showCategoryForm({ExpenseCategory? category}) async {
    final nameController = TextEditingController(text: category?.name);
    final iconUrlController = TextEditingController(text: category?.iconUrl);
    final user = FirebaseAuth.instance.currentUser;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Update Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: iconUrlController,
              decoration: const InputDecoration(labelText: 'Icon URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final icon = iconUrlController.text.trim();
              if (name.isEmpty || icon.isEmpty || user == null) return;
              final col = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('expenseCategories');
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(ExpenseCategory category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Deleting this category will also delete all related expenses. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final db = FirebaseFirestore.instance;
      final catRef = db
          .collection('users')
          .doc(user.uid)
          .collection('expenseCategories')
          .doc(category.id);
      final expenseSnap = await db
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('categoryId', isEqualTo: category.id)
          .get();
      for (var doc in expenseSnap.docs) {
        await doc.reference.delete();
      }
      await catRef.delete();
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
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return ListTile(
              leading: Image.network(cat.iconUrl, width: 30, height: 30),
              title: Text(cat.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showCategoryForm(category: cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteCategory(cat),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _showCategoryForm(),
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