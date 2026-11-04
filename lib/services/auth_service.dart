import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

/// Firebase Authentication (RF01, RF02, RF03).
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    await _requireOrMigrateProfile(credential.user);
  }

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
    // Google access is also the registration path. If this Authentication
    // account survived after its Firestore profile was removed, recreate a
    // student profile so the selected Google account can enter again. Existing
    // profiles (including legacy personal roles) are kept as they are.
    await _requireOrMigrateProfile(credential.user, createIfNew: true);
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
    await _db.collection('usuarios').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'role': 'estudiante',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Uses Spanish collection names. A legacy profile is moved on its owner's
  /// next sign-in so existing roles survive the collection rename.
  static Future<void> _requireOrMigrateProfile(User? user,
      {bool createIfNew = false}) async {
    if (user == null) return;
    final ref = _db.collection('usuarios').doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;

    final legacyRef = _db.collection('users').doc(user.uid);
    final legacy = await legacyRef.get();
    if (legacy.exists) {
      await ref.set(legacy.data()!);
      return;
    }

    if (createIfNew) {
      await ref.set({
        'name': user.displayName ?? user.email?.split('@').first ?? 'Usuario',
        'email': user.email ?? '',
        'role': 'estudiante',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await _auth.signOut();
    throw const UserProfileMissingException();
  }

  static Future<void> logout() => _auth.signOut();

  static Stream<AppUser> currentUser() async* {
    final user = _auth.currentUser;
    if (user == null) throw const UserProfileMissingException();
    // Also migrates the current session, so users do not need to sign out just
    // because this app switched from the old collection name.
    // Firebase emits authStateChanges before the Google popup handler finishes
    // writing its Firestore profile. Provision here too to avoid racing that
    // write and signing the user straight back out.
    final signedInWithGoogle = user.providerData
        .any((provider) => provider.providerId == 'google.com');
    await _requireOrMigrateProfile(user, createIfNew: signedInWithGoogle);
    await for (final snapshot
        in _db.collection('usuarios').doc(user.uid).snapshots()) {
      if (!snapshot.exists) throw const UserProfileMissingException();
      yield AppUser.fromDoc(snapshot);
    }
  }
}

class UserProfileMissingException implements Exception {
  const UserProfileMissingException();

  @override
  String toString() =>
      'Esta cuenta existe en Firebase Authentication, pero no tiene un perfil en Firestore. Se bloqueó el acceso a PawTrack. Si eliminaste el perfil por error, un administrador debe restaurarlo en usuarios.';
}
