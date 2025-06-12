import 'package:cloud_firestore/cloud_firestore.dart';

class IncomeAllocation {
  final String id;
  final String incomeId;        
  final String targetId;        
  final double amount;

  IncomeAllocation({
    required this.id,
    required this.incomeId,
    required this.targetId,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'incomeId': incomeId,
      'targetId': targetId,
      'amount': amount,
    };
  }

  factory IncomeAllocation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IncomeAllocation(
      id: doc.id,
      incomeId: data['incomeId'] ?? '',
      targetId: data['targetId'] ?? '',
      amount: data['amount']?.toDouble() ?? 0.0,
    );
  }

  
}