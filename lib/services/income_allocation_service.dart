import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/incomeAllocation.dart';

class IncomeAllocationService {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  CollectionReference? getCollection() {
    final user = auth.currentUser;
    if (user == null) return null;
    
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('incomeAllocations');
  }

  Future<void> saveAllocations(String incomeId, Map<String, double> allocations) async {
    final collection = getCollection();
    if (collection == null) return;

    try {
      for (final entry in allocations.entries) {
        if (entry.value > 0) {
          final allocation = IncomeAllocation(
            id: '', 
            incomeId: incomeId,
            targetId: entry.key, 
            amount: entry.value,
          );

          await collection.add(allocation.toMap());
        }
      }
    } catch (e) {
      print('Error saving allocations: $e');
    }
  }

  Future<Map<String, double>> getIncomeAllocations(String incomeId) async {
    final collection = getCollection();
    if (collection == null) return {};

    try {
      final docs = await collection
          .where('incomeId', isEqualTo: incomeId)
          .get();

      Map<String, double> result = {};
      for (var doc in docs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final targetId = data['targetId'] as String;
        final amount = (data['amount'] as num).toDouble();
        result[targetId] = amount;
      }
      
      return result;
    } catch (e) {
      print('Error getting allocations: $e');
      return {};
    }
  }
  
  Future<void> deleteAllocationsByTargetId(String targetId) async {
    final collection = getCollection();
    if (collection == null) return;

    try {
      final docs = await collection
          .where('targetId', isEqualTo: targetId)
          .get();

      for (var doc in docs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting allocations by targetId: $e');
    }
  }

  Future<void> updateAllocations(String incomeId, Map<String, double> newAllocations) async {
    final collection = getCollection();
    if (collection == null) return;

    try {
      final oldDocs = await collection
          .where('incomeId', isEqualTo: incomeId)
          .get();

      for (var doc in oldDocs.docs) {
        await doc.reference.delete();
      }

      for (final entry in newAllocations.entries) {
        if (entry.value > 0) {
          final allocation = IncomeAllocation(
            id: '', 
            incomeId: incomeId,
            targetId: entry.key, 
            amount: entry.value,
          );

          await collection.add(allocation.toMap());
        }
      }
    } catch (e) {
      print('Error updating allocations: $e');
    }
  }

  Future<void> deleteIncomeAllocations(String incomeId) async {
    final collection = getCollection();
    if (collection == null) return;

    try {
      final docs = await collection
          .where('incomeId', isEqualTo: incomeId)
          .get();

      for (var doc in docs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting allocations: $e');
    }
  }

  Future<double> getTotalAllocated(String incomeId) async {
    final allocations = await getIncomeAllocations(incomeId);
    double total = 0;
    for (double amount in allocations.values) {
      total += amount;
    }
    return total;
  }
}