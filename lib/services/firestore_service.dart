import 'package:cloud_firestore/cloud_firestore.dart';

class Firestoreservice {

  static const String usersCollection = 'users';
  static final CollectionReference users = FirebaseFirestore.instance.collection(usersCollection);

  Future createUserProfile(String uid, String name, String email) {
    return users.doc(uid).set({
      'name': name,
      'email': email,
      'createdAt': Timestamp.now(),
    });
  }

  Stream getUserProfile(String uid) {
    return users.doc(uid).snapshots();
  }

  Future updateUserProfile(String uid, String name, String email) {
    return users.doc(uid).update({
      'name': name,
      'email': email,
      'updatedAt': Timestamp.now(),
    });
  }

  Future deleteUserProfile(String uid) {
    return users.doc(uid).delete();
  }

}