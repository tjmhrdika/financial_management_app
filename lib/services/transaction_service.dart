import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financial_management_app/models/expense.dart';
import 'package:financial_management_app/models/expense_category.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Expense>> fetchLatestTransactions(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    String collection = (type == 'Income') ? 'income' : 'expenses';
    if (user == null) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection(collection)
        .orderBy('date', descending: true)
        .limit(2)
        .get();
    
    return snapshot.docs.map((doc) => Expense.fromDoc(doc)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCategorySummaries(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    String collection = (type == 'Income') ? 'income' : 'expenses';
    String categoryCollection = (type == 'Income') ? 'incomeCategories' : 'expenseCategories';
    if (user == null) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection(collection)
        .get();
        
    
    final expenses = snapshot.docs.map((doc) => Expense.fromDoc(doc)).toList();


    
  Map<String, double> groupedSums = {};
    for (var expense in expenses) {
      groupedSums[expense.categoryId] =
          (groupedSums[expense.categoryId] ?? 0) + expense.amount;
    }


   List<Map<String, dynamic>> result = [];

    for (var categoryId in groupedSums.keys) {
      DocumentSnapshot docSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(categoryCollection)
          .doc(categoryId)
          .get();

      final category = docSnapshot.exists
          ? ExpenseCategory.fromDoc(docSnapshot)
          : ExpenseCategory(
              id: categoryId,
              name: 'Unknown',
              iconUrl: 'https://cdn-icons-png.freepik.com/512/3524/3524335.png',
            );
      
      result.add({
        'category': category,
        'total': groupedSums[categoryId],
      });
    }

    return result;
  }

}
