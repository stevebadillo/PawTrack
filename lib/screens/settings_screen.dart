import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
      children: [
        const SizedBox(height: 10),

        // ── Usar mi ubicación ──
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _SettingToggleTile(
                icon: Icons.location_on_outlined,
                title: 'Usar mi ubicación',
                initialValue: true,
              ),
              const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(Icons.lock_outline,
                    color: Color(0xFF0F3E7D), size: 22),
                title: const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF0B2545)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _ChangePasswordScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: AuthService.logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Toggle tile with local state ──
class _SettingToggleTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool initialValue;
  const _SettingToggleTile({
    required this.icon,
    required this.title,
    required this.initialValue,
  });
  @override
  State<_SettingToggleTile> createState() => _SettingToggleTileState();
}

class _SettingToggleTileState extends State<_SettingToggleTile> {
  late bool _value;
  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: Icon(widget.icon, color: const Color(0xFF0F3E7D), size: 22),
      title: Text(widget.title,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF0B2545))),
      value: _value,
      activeColor: const Color(0xFF0D3B73),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onChanged: (v) => setState(() => _value = v),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMBIAR CONTRASEÑA SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen();
  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _showCurrent = false, _showNew = false, _showConfirm = false;
  bool _saving = false;

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_currentPw.text.isEmpty) {
      _snack('Ingresa tu contraseña actual.');
      return;
    }
    if (_newPw.text.length < 8) {
      _snack('La nueva contraseña debe tener mínimo 8 caracteres.');
      return;
    }
    if (_newPw.text != _confirmPw.text) {
      _snack('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _snack('No se pudo obtener la sesión actual.');
        return;
      }
      // Re‑authenticate
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _currentPw.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPw.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente.')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final msg = switch (e.code) {
          'wrong-password' => 'La contraseña actual es incorrecta.',
          'weak-password' =>
            'La nueva contraseña es muy débil. Usa al menos 8 caracteres.',
          'requires-recent-login' =>
            'Tu sesión expiró. Cierra sesión e inicia de nuevo.',
          _ => 'Error: ${e.message ?? e.code}',
        };
        _snack(msg);
      }
    } catch (e) {
      if (mounted) _snack('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _forgotPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      _snack('No hay un correo asociado a esta cuenta.');
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) {
        _snack(
            'Se envió un enlace de recuperación a $email. Revisa tu correo.');
      }
    } catch (e) {
      if (mounted) _snack('No se pudo enviar el correo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Icon(Icons.chevron_left_rounded,
                          color: Color(0xFF0F2B48), size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2B48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          const Text(
            'Para proteger tu cuenta, ingresa tu contraseña actual y elige una nueva.',
            style: TextStyle(
                color: Color(0xFF64748B), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Contraseña actual
          _pwField(
            controller: _currentPw,
            label: 'Contraseña actual',
            hint: 'Ingresa tu contraseña actual',
            show: _showCurrent,
            onToggle: () =>
                setState(() => _showCurrent = !_showCurrent),
            highlighted: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                    color: Color(0xFF1E5BB0),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Nueva contraseña
          _pwField(
            controller: _newPw,
            label: 'Nueva contraseña',
            hint: 'Mínimo 8 caracteres',
            show: _showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
          ),
          const SizedBox(height: 16),

          // Confirmar
          _pwField(
            controller: _confirmPw,
            label: 'Confirmar nueva contraseña',
            hint: 'Repite la nueva contraseña',
            show: _showConfirm,
            onToggle: () =>
                setState(() => _showConfirm = !_showConfirm),
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B73),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 20),
              label: const Text('Guardar contraseña',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pwField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool show,
    required VoidCallback onToggle,
    bool highlighted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF0D3B73)
              : const Color(0xFFE2E8F0),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: !show,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 12),
          hintText: hint,
          hintStyle:
              const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.lock_outline,
              size: 20, color: Color(0xFF64748B)),
          suffixIcon: IconButton(
            icon: Icon(
              show
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF64748B),
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
