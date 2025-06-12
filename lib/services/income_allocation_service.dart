// services/income_allocation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/incomeAllocation.dart';

class IncomeAllocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _getAllocationsCollection() {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('incomeAllocations');
  }

  Future<void> saveAllocations(String incomeId, Map<String, double> goalAllocations) async {
    final collection = _getAllocationsCollection();
    if (collection == null) throw Exception('User not authenticated');

    try {
      final batch = _firestore.batch();

      for (final entry in goalAllocations.entries) {
        if (entry.value > 0) {
          final allocation = IncomeAllocation(
            id: '', 
            incomeId: incomeId,
            targetId: entry.key, 
            amount: entry.value,
          );

          final docRef = collection.doc();
          batch.set(docRef, allocation.toMap());
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save allocations: $e');
    }
  }
}