import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/ai_avatar_service.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<String> _styles = AvatarService.userStyles;

  final ImagePicker _picker = ImagePicker();

  late String _style;
  late String _seed;
  Uint8List? _avatarBytes;
  bool _savingAvatar = false;

  String get _userKey {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (authUid.isNotEmpty) return authUid;
    if (widget.user.email.isNotEmpty) return widget.user.email;
    return widget.user.name;
  }

  @override
  void initState() {
    super.initState();
    _style = AvatarService.defaultUserStyle;
    _seed = _userKey;
    _loadSavedAvatar();
  }

  String _dicebearUrl(String style, String seed, {int size = 160}) =>
      AvatarService.userAvatarUrl(seed: seed, style: style, size: size);

  Future<void> _loadSavedAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final data = doc.data();
      if (data != null && mounted) {
        final savedStyle = data['avatarStyle'] as String?;
        final savedSeed = data['avatarSeed'] as String?;
        final savedBase64 = data['avatarBase64'] as String?;

        Uint8List? decodedBytes;
        if (savedBase64 != null && savedBase64.isNotEmpty) {
          try {
            decodedBytes = base64Decode(savedBase64);
          } catch (_) {
            decodedBytes = null;
          }
        }

        setState(() {
          if (savedStyle != null && _styles.contains(savedStyle)) {
            _style = savedStyle;
          }
          if (savedSeed != null && savedSeed.isNotEmpty) {
            _seed = savedSeed;
          }
          if (decodedBytes != null && decodedBytes.isNotEmpty) {
            _avatarBytes = decodedBytes;
          } else {
            _avatarBytes = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _persistDicebearAvatar(String newStyle, String newSeed) async {
    setState(() {
      _style = newStyle;
      _seed = newSeed;
      _avatarBytes = null;
      _savingAvatar = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .set(
          {
            'avatarType': 'dicebear',
            'avatarStyle': newStyle,
            'avatarSeed': newSeed,
            'avatarBase64': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo guardar el avatar: $e')),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _savingAvatar = false);
    }
  }

  Future<void> _pickAndPersistPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      // Firestore tiene límite de ~1 MB por documento; cuidamos el tamaño del base64.
      if (bytes.length > 700000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La imagen es muy pesada. Elige una más ligera.'),
            ),
          );
        }
        return;
      }

      final encoded = base64Encode(bytes);
      setState(() {
        _avatarBytes = bytes;
        _savingAvatar = true;
      });

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .set(
          {
            'avatarType': 'photo',
            'avatarBase64': encoded,
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo subir la foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingAvatar = false);
      }
    }
  }

  ImageProvider _currentAvatarImage({
    String? tempStyle,
    String? tempSeed,
    Uint8List? tempBytes,
    int size = 160,
  }) {
    if (tempBytes != null && tempBytes.isNotEmpty) {
      return MemoryImage(tempBytes);
    }
    if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
      return MemoryImage(_avatarBytes!);
    }
    return NetworkImage(
      _dicebearUrl(tempStyle ?? _style, tempSeed ?? _seed, size: size),
    );
  }

  void _openAvatarPicker() {
    String tempStyle = _style;
    String tempSeed = _seed;
    Uint8List? tempBytes = _avatarBytes;
    bool tempIsAi = false;
    bool generatingAi = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Personalizar avatar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFEBF3FF),
                    backgroundImage: generatingAi
                        ? null
                        : _currentAvatarImage(
                            tempStyle: tempStyle,
                            tempSeed: tempSeed,
                            tempBytes: tempBytes,
                            size: 200,
                          ),
                    child: generatingAi
                        ? const CircularProgressIndicator()
                        : null,
                  ),
                  if (generatingAi)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Creando tu avatar con IA… puede tardar hasta un minuto.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            tempBytes = null;
                            tempIsAi = false;
                            tempSeed = '${_userKey}_${Random().nextInt(999999)}';
                          });
                        },
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('Generar variación'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F3E7D),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 80,
                          );
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          if (bytes.isEmpty) return;
                          if (bytes.length > 700000) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'La imagen es muy pesada. Elige una más ligera.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          setModalState(() {
                            tempBytes = bytes;
                            tempIsAi = false;
                          });
                        },
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: const Text('Subir foto'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F3E7D),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Sube una foto y la convierte en avatar con IA
                      // (Pollinations, model=kontext).
                      FilledButton.tonalIcon(
                        onPressed: generatingAi
                            ? null
                            : () async {
                                final picked = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  maxHeight: 1024,
                                  imageQuality: 85,
                                );
                                if (picked == null) return;
                                final photo = await picked.readAsBytes();
                                if (photo.isEmpty) return;
                                setModalState(() => generatingAi = true);
                                try {
                                  final avatar =
                                      await AiAvatarService.avatarFromPhoto(
                                          photo);
                                  if (avatar.length > 700000) {
                                    throw const AiAvatarException(
                                        'El avatar generado es muy pesado. Intenta de nuevo.');
                                  }
                                  setModalState(() {
                                    tempBytes = avatar;
                                    tempIsAi = true;
                                  });
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => generatingAi = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Crear avatar con IA'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Estilo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _styles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final style = _styles[index];
                        final selected = tempBytes == null && style == tempStyle;
                        final itemUrl =
                            _dicebearUrl(style, tempSeed, size: 120);

                        return GestureDetector(
                          onTap: () => setModalState(() {
                            tempBytes = null;
                            tempIsAi = false;
                            tempStyle = style;
                          }),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF0F3E7D)
                                        : const Color(0xFFE2E8F0),
                                    width: selected ? 2.5 : 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  backgroundImage: NetworkImage(itemUrl),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                style,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? const Color(0xFF0F3E7D)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3E7D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: generatingAi
                          ? null
                          : () async {
                        // Se toma el messenger de la pantalla (no del modal)
                        // antes de cerrar el modal y de esperar a Firestore.
                        final messenger = ScaffoldMessenger.of(this.context);
                        Navigator.pop(modalContext);
                        if (tempBytes != null) {
                          final encoded = base64Encode(tempBytes!);
                          setState(() {
                            _avatarBytes = tempBytes;
                            _savingAvatar = true;
                          });
                          final uid =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          if (uid.isNotEmpty) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('usuarios')
                                  .doc(uid)
                                  .set(
                                {
                                  'avatarType': tempIsAi ? 'ai' : 'photo',
                                  'avatarBase64': encoded,
                                },
                                SetOptions(merge: true),
                              );
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo guardar la foto: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                          if (mounted) setState(() => _savingAvatar = false);
                        } else {
                          _persistDicebearAvatar(tempStyle, tempSeed);
                        }
                      },
                      child: const Text(
                        'Guardar avatar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackLetter =
        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _openAvatarPicker,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFF0F3E7D),
                      backgroundImage: _currentAvatarImage(size: 160),
                      onBackgroundImageError: (_, __) {},
                      child: _savingAvatar
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              fallbackLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B2545),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0B2545),
                ),
              ),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: _openAvatarPicker,
                    child: const Text(
                      'Personalizar avatar',
                      style: TextStyle(
                        color: Color(0xFF0F3E7D),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickAndPersistPhoto,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text(
                      'Subir foto',
                      style: TextStyle(
                        color: Color(0xFF1E5BB0),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                const _SettingToggleTile(
                  icon: Icons.location_on_outlined,
                  title: 'Usar mi ubicación',
                  initialValue: true,
                ),
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFF1F5F9),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF0F3E7D),
                    size: 22,
                  ),
                  title: const Text(
                    'Cambiar contraseña',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _ChangePasswordScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: AuthService.logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

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
      title: Text(
        widget.title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF0B2545),
        ),
      ),
      value: _value,
      activeTrackColor: const Color(0xFF0D3B73),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      onChanged: (v) => setState(() => _value = v),
    );
  }
}

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
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPw.text,
      );
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
          'Se envió un enlace de recuperación a $email. Revisa tu correo.',
        );
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
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFF0F2B48),
                        size: 26,
                      ),
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
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _pwField(
            controller: _currentPw,
            label: 'Contraseña actual',
            hint: 'Ingresa tu contraseña actual',
            show: _showCurrent,
            onToggle: () => setState(() => _showCurrent = !_showCurrent),
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
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _pwField(
            controller: _newPw,
            label: 'Nueva contraseña',
            hint: 'Mínimo 8 caracteres',
            show: _showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
          ),
          const SizedBox(height: 16),
          _pwField(
            controller: _confirmPw,
            label: 'Confirmar nueva contraseña',
            hint: 'Repite la nueva contraseña',
            show: _showConfirm,
            onToggle: () => setState(() => _showConfirm = !_showConfirm),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B73),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: const Text(
                'Guardar contraseña',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
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
            fontSize: 12,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(
            Icons.lock_outline,
            size: 20,
            color: Color(0xFF64748B),
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
