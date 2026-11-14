import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

// ============================================================================
// SERVICIO DE AUTENTICACIÓN (AuthService)
// Gestiona el inicio de sesión, registro de usuarios, recuperación de
// contraseña, acceso con Google y lectura del perfil desde Firestore.
// ============================================================================
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // --------------------------------------------------------------------------
  // INICIO DE SESIÓN CON CORREO Y CONTRASEÑA
  // Autentica las credenciales y verifica que el usuario tenga perfil en Firestore
  // --------------------------------------------------------------------------
  static Future<void> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    await _requireOrMigrateProfile(credential.user);
  }

  // --------------------------------------------------------------------------
  // INICIO DE SESIÓN O REGISTRO CON CUENTA DE GOOGLE
  // Soporta tanto entorno web (popup) como móvil (GoogleSignIn). Si el usuario
  // entra por primera vez con Google, le crea automáticamente su perfil.
  // --------------------------------------------------------------------------
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
    await _requireOrMigrateProfile(credential.user, createIfNew: true);
    return credential;
  }

  // --------------------------------------------------------------------------
  // RECUPERACIÓN DE CONTRASEÑA
  // Envía el correo oficial de Firebase con el enlace para crear una nueva clave
  // --------------------------------------------------------------------------
  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // --------------------------------------------------------------------------
  // REGISTRO DE NUEVO USUARIO
  // Crea el usuario en Firebase Authentication y guarda su documento inicial
  // en la colección 'usuarios' con el rol por defecto 'estudiante'.
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // VERIFICACIÓN DEL PERFIL DE USUARIO EN FIRESTORE
  // Comprueba que exista el documento en la colección 'usuarios' o lo crea
  // automáticamente si ingresa por primera vez con Google.
  // --------------------------------------------------------------------------
  static Future<void> _requireOrMigrateProfile(User? user,
      {bool createIfNew = false}) async {
    if (user == null) return;
    final ref = _db.collection('usuarios').doc(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) return;

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

  // --------------------------------------------------------------------------
  // CIERRE DE SESIÓN
  // Finaliza la sesión activa en Firebase Authentication
  // --------------------------------------------------------------------------
  static Future<void> logout() => _auth.signOut();

  // --------------------------------------------------------------------------
  // FLUJO EN TIEMPO REAL DEL USUARIO ACTUAL
  // Escucha los cambios en el documento del usuario en la colección 'usuarios'
  // --------------------------------------------------------------------------
  static Stream<AppUser> currentUser() async* {
    final user = _auth.currentUser;
    if (user == null) throw const UserProfileMissingException();
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

// ============================================================================
// EXCEPCIÓN DE PERFIL FALTANTE EN FIRESTORE
// Se lanza cuando una cuenta existe en Auth pero fue borrada de Firestore.
// ============================================================================
class UserProfileMissingException implements Exception {
  const UserProfileMissingException();

  @override
  String toString() =>
      'Esta cuenta existe en Firebase Authentication, pero no tiene un perfil en Firestore. Se bloqueó el acceso a PawTrack. Si eliminaste el perfil por error, un administrador debe restaurarlo en usuarios.';
}
