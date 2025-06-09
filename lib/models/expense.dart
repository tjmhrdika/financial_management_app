import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final DateTime date;
  final String description;
  final int amount;
  final String categoryId;

  Expense({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.categoryId,
  });

  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'description': description,
    'amount': amount,
    'categoryId': categoryId,
  };

  factory Expense.fromDoc(DocumentSnapshot doc) => Expense(
    id: doc.id,
    date: (doc['date'] as Timestamp).toDate(),
    description: doc['description'],
    amount: doc['amount'],
    categoryId: doc['categoryId'],
  );
}