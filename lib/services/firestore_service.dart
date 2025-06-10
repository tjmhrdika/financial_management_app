import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:financial_management_app/models/users.dart';

class FirestoreService {
  static const String usersCollection = 'users';
  static final CollectionReference _users = FirebaseFirestore.instance.collection(usersCollection);

  static Future<void> createUserProfile(UserModel user) async {
    return _users.doc(user.uid).set(user.toMap());
  }

  static Future<UserModel?> getUserProfile(String uid) async {
    DocumentSnapshot doc = await _users.doc(uid).get();
    
    if (doc.exists) {
      return UserModel.fromSnapshot(doc);
    }
    return null;
  }

  static Stream<UserModel?> getUserProfileStream(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserModel.fromSnapshot(snapshot);
      }
      return null;
    });
  }

  static Future<bool> usernameExists(String username) async {
    QuerySnapshot query = await _users
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    
    return query.docs.isNotEmpty;
  }

  static Future<void> updateUsername(String uid, String username) async {
    return _users.doc(uid).update({
      'username': username,
      'updatedAt': Timestamp.now(),
    });
  }
}