import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final String iconUrl;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconUrl,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'iconUrl': iconUrl,
  };

  factory ExpenseCategory.fromDoc(DocumentSnapshot doc) => ExpenseCategory(
    id: doc.id,
    name: doc['name'],
    iconUrl: doc['iconUrl'],
  );
}