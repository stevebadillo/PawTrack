import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

/// Firebase Authentication (RF01, RF02, RF03).
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> login(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<UserCredential?> loginWithGoogle() async {
    late final UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final account = await GoogleSignIn(scopes: const ['email']).signIn();
      if (account == null) return null;
      final tokens = await account.authentication;
      final oauth = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      credential = await _auth.signInWithCredential(oauth);
    }
    await _ensureUserProfile(credential.user);
    return credential;
  }

  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Todo usuario nuevo es 'estudiante'. El rol 'personal' lo asigna
  /// un administrador desde la consola de Firebase.
  static Future<void> register(
      String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'role': 'estudiante',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _ensureUserProfile(User? user) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        'name': user.displayName ?? user.email?.split('@').first ?? 'Usuario',
        'email': user.email ?? '',
        'role': 'estudiante',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> logout() => _auth.signOut();

  static Stream<AppUser> currentUser() {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).snapshots().map(AppUser.fromDoc);
  }
}
