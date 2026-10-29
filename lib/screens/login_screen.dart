import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false, _loading = false, _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_register) {
        await AuthService.register(
            _name.text.trim(), _email.text.trim(), _pass.text);
      } else {
        await AuthService.login(_email.text.trim(), _pass.text);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } catch (_) {
      _showError(
          'No se pudo conectar. Revisa tu conexión e inténtalo otra vez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.loginWithGoogle();
      if (result == null && mounted) {
        _showError('Inicio con Google cancelado.');
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } catch (_) {
      _showError(
          'No se pudo iniciar con Google. Verifica que Google esté habilitado en Firebase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Escribe tu correo para enviarte el enlace de recuperación.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Enviamos un enlace de recuperación a $email')),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _firebaseMessage(FirebaseAuthException e) => switch (e.code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Correo o contraseña incorrectos.',
        'email-already-in-use' =>
          'Ya existe una cuenta con ese correo. Inicia sesión.',
        'weak-password' => 'Usa una contraseña de al menos 6 caracteres.',
        'invalid-email' => 'El correo no tiene un formato válido.',
        'account-exists-with-different-credential' =>
          'Ese correo ya tiene una cuenta con otro método. Inicia sesión con ese método para conservar tu cuenta.',
        'operation-not-allowed' =>
          'Este método de acceso aún no está habilitado en Firebase.',
        'popup-closed-by-user' =>
          'Cerraste la ventana de Google antes de terminar.',
        'network-request-failed' =>
          'No hay conexión con Firebase. Revisa tu internet.',
        _ => e.message ?? 'No se pudo completar el acceso. Inténtalo otra vez.',
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _register
                            ? 'Únete a PawTrack'
                            : 'Bienvenido a PawTrack',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cuidamos juntos a los perros de la ESPOCH',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Escribe tu nombre.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) => v == null || !v.trim().contains('@')
                            ? 'Escribe un correo válido.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _pass,
                        obscureText: _hidePassword,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password
                        ],
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Usa al menos 6 caracteres.'
                            : null,
                        onFieldSubmitted: (_) => _loading ? null : _submit(),
                      ),
                      if (!_register)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text('Olvidé mi contraseña')),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_register
                                ? Icons.person_add_alt_1
                                : Icons.login),
                        label:
                            Text(_register ? 'Crear cuenta' : 'Iniciar sesión'),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('o continúa con',
                              style: TextStyle(color: colors.onSurfaceVariant)),
                        ),
                        const Expanded(child: Divider())
                      ]),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _loginWithGoogle,
                        icon: const Text('G',
                            style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontWeight: FontWeight.w800,
                                fontSize: 19)),
                        label: const Text('Continuar con Google'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _register = !_register),
                        child: Text(_register
                            ? '¿Ya tienes cuenta? Inicia sesión'
                            : '¿Primera vez? Crea una cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
