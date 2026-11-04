import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// ============================================================================
// MODOS DE PANTALLA DE AUTENTICACIÓN
// Define cuál de las 3 vistas se muestra actualmente:
// 1. login: Pantalla de inicio de sesión ("Bienvenido(a) PawTrack")
// 2. register: Pantalla de creación de cuenta ("Crea tu cuenta")
// 3. forgotPassword: Pantalla de recuperación ("¿Olvidaste tu contraseña?")
// ============================================================================
enum _AuthViewMode { login, register, forgotPassword }

// ============================================================================
// PANTALLA DE AUTENTICACIÓN (LOGIN, REGISTRO Y RECUPERACIÓN)
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --------------------------------------------------------------------------
  // CONTROLADORES Y VARIABLES DE ESTADO
  // Almacenan el texto ingresado por el usuario y el estado visual de la vista
  // --------------------------------------------------------------------------
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();

  _AuthViewMode _mode = _AuthViewMode.login;
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  // --------------------------------------------------------------------------
  // LIBERACIÓN DE RECURSOS
  // Limpia los controladores de texto cuando se destruye la pantalla
  // --------------------------------------------------------------------------
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // CAMBIO ENTRE VISTAS (LOGIN / REGISTRO / RECUPERAR CONTRASEÑA)
  // Permite navegar entre las 3 pantallas limpiando el foco del teclado
  // --------------------------------------------------------------------------
  void _switchMode(_AuthViewMode newMode) {
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = newMode;
    });
  }

  // --------------------------------------------------------------------------
  // LÓGICA DE INICIO DE SESIÓN Y REGISTRO CON CORREO Y CONTRASEÑA
  // Valida los campos según la vista activa y se comunica con AuthService
  // --------------------------------------------------------------------------
  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text;
    final confirmPass = _confirmPass.text;

    // Validación del nombre en modo registro
    if (_mode == _AuthViewMode.register && name.isEmpty) {
      _showError('Por favor ingresa tu nombre completo.');
      return;
    }

    // Validación del formato de correo electrónico
    if (email.isEmpty || !email.contains('@')) {
      _showError('Por favor escribe un correo electrónico válido.');
      return;
    }

    // Validación de la contraseña según el modo
    if (_mode == _AuthViewMode.register) {
      if (pass.length < 8) {
        _showError('La contraseña debe tener mínimo 8 caracteres.');
        return;
      }
      if (pass != confirmPass) {
        _showError('Las contraseñas no coinciden. Verifica e inténtalo de nuevo.');
        return;
      }
    } else {
      if (pass.length < 6) {
        _showError('Ingresa tu contraseña (mínimo 6 caracteres).');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      if (_mode == _AuthViewMode.register) {
        // Registra un nuevo usuario en Firebase Auth y crea su perfil en Firestore
        await AuthService.register(name, email, pass);
      } else {
        // Inicia sesión con un usuario existente
        await AuthService.login(email, pass);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } on UserProfileMissingException catch (e) {
      _showError(e.toString());
    } catch (_) {
      _showError('No se pudo conectar. Revisa tu conexión e inténtalo otra vez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------------------------------
  // LÓGICA DE INICIO DE SESIÓN CON GOOGLE
  // Abre el selector de cuentas de Google y autentica al usuario en Firebase
  // --------------------------------------------------------------------------
  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.loginWithGoogle();
      if (result == null && mounted) {
        _showError('Inicio con Google cancelado.');
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } on UserProfileMissingException catch (e) {
      _showError(e.toString());
    } catch (_) {
      _showError(
        'No se pudo completar el acceso con Google. Comprueba la conexión y las reglas de Firestore para la colección usuarios.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------------------------------
  // LÓGICA DE RECUPERACIÓN DE CONTRASEÑA
  // Envía un enlace de restablecimiento al correo electrónico indicado
  // --------------------------------------------------------------------------
  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Escribe tu correo electrónico para enviarte el enlace de recuperación.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enviamos un enlace de recuperación a $email')),
        );
        _switchMode(_AuthViewMode.login);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------------------------------
  // UTILIDAD PARA MOSTRAR MENSAJES EMERGENTES (SNACKBAR)
  // Muestra alertas o errores en la parte inferior de la pantalla
  // --------------------------------------------------------------------------
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------------------
  // TRADUCCIÓN DE CÓDIGOS DE ERROR DE FIREBASE A ESPAÑOL
  // Convierte los errores técnicos de Firebase en mensajes claros para el usuario
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // CONSTRUCCIÓN PRINCIPAL DE LA INTERFAZ (BUILD)
  // Selecciona y dibuja la vista correspondiente según el modo activo (_mode)
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _mode == _AuthViewMode.login,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mode != _AuthViewMode.login) {
          _switchMode(_AuthViewMode.login);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFCFF),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: switch (_mode) {
                _AuthViewMode.login => _buildLoginView(),
                _AuthViewMode.forgotPassword => _buildForgotPasswordView(),
                _AuthViewMode.register => _buildRegisterView(),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // BLOQUE 1: VISTA DE INICIO DE SESIÓN ("Bienvenido(a) PawTrack")
  // Contiene la marca de agua de huella, logo central, campos de acceso,
  // botón de inicio de sesión, acceso con Google y enlace para crear cuenta.
  // ==========================================================================
  Widget _buildLoginView() {
    return Stack(
      children: [
        // Marca de agua decorativa de huella en la esquina superior derecha
        const Positioned(
          top: -10,
          right: -18,
          child: IgnorePointer(
            child: _PawWatermark(),
          ),
        ),

        // Contenido desplazable del formulario de inicio de sesión
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),

              // Logo principal centrado con sombra suave
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A1E3C).withOpacity(0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Título de bienvenida en dos líneas y colores institucionales
              const Text(
                'Bienvenido(a)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1E36),
                  height: 1.15,
                  letterSpacing: -0.4,
                ),
              ),
              const Text(
                'PawTrack',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D4F91),
                  height: 1.2,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),

              // Subtítulo descriptivo de la aplicación
              const Text(
                'Cuidemos juntos a los perros de la ESPOCH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 28),

              // Campo de Correo electrónico
              _AuthInputCard(
                label: 'Correo electrónico',
                hintText: 'nombre@correo.com',
                controller: _email,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 14),

              // Campo de Contraseña con botón para mostrar/ocultar
              _AuthInputCard(
                label: 'Contraseña',
                hintText: 'Ingresa tu contraseña',
                controller: _pass,
                prefixIcon: Icons.lock_open_rounded,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _loading ? null : _submit(),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Enlace para ir a la vista de "¿Olvidaste tu contraseña?"
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D4F91),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _loading
                      ? null
                      : () => _switchMode(_AuthViewMode.forgotPassword),
                  child: const Text(
                    'Olvidé mi contraseña',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón primario "Iniciar sesión"
              _PrimaryAuthButton(
                label: 'Iniciar sesión',
                icon: Icons.login_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 22),

              // Divisor horizontal con el texto "o continúa con"
              Row(
                children: const [
                  Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'o continúa con',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                ],
              ),
              const SizedBox(height: 18),

              // Botón de acceso rápido "Continuar con Google"
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loading ? null : _loginWithGoogle,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _GoogleLogoIcon(size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Continuar con Google',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),

              // Enlace inferior "¿Primera vez? Crea una cuenta"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Primera vez? ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : () => _switchMode(_AuthViewMode.register),
                    child: const Text(
                      'Crea una cuenta',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1D4F91),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BLOQUE 2: VISTA DE RECUPERACIÓN ("¿Olvidaste tu contraseña?")
  // Muestra la barra superior con botón de regreso y minilogo, título grande,
  // instrucciones, campo de correo electrónico y botón "Enviar enlace".
  // ==========================================================================
  Widget _buildForgotPasswordView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado superior: botón volver a la izquierda y logo a la derecha
          _buildTopHeader(),
          const SizedBox(height: 18),

          // Título principal centrado
          const Text(
            '¿Olvidaste tu\ncontraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B1E36),
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 22),

          // Texto explicativo para el usuario
          const Text(
            'Ingresa tu correo y te enviaremos un enlace para crear una nueva.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Campo para ingresar el correo de recuperación
          _AuthInputCard(
            label: 'Correo electrónico',
            hintText: 'nombre@correo.com',
            controller: _email,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            highlightBorder: true,
            onSubmitted: (_) => _loading ? null : _forgotPassword(),
          ),
          const SizedBox(height: 20),

          // Botón primario "Enviar enlace"
          _PrimaryAuthButton(
            label: 'Enviar enlace',
            icon: Icons.send_outlined,
            loading: _loading,
            onPressed: _forgotPassword,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BLOQUE 3: VISTA DE REGISTRO DE USUARIO ("Crea tu cuenta")
  // Contiene el encabezado con botón atrás y logo, título, subtítulo,
  // 4 campos (nombre, correo, contraseña, confirmar contraseña),
  // botón "Crear cuenta" y texto inferior de Términos y Política de privacidad.
  // ==========================================================================
  Widget _buildRegisterView() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado superior: botón volver y logo de PawTrack
                _buildTopHeader(),
                const SizedBox(height: 10),

                // Título de la pantalla de registro
                const Text(
                  'Crea tu cuenta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0B1E36),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Subtítulo motivador para el registro en el campus
                const Text(
                  'Regístrate para reportar y seguir a los perros del campus.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),

                // 1. Campo de Nombre completo (sin ícono izquierdo, alineado al texto)
                _AuthInputCard(
                  label: 'Nombre completo',
                  hintText: 'Nombre y apellido',
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  highlightBorder: true,
                  indentWithoutIcon: true,
                ),
                const SizedBox(height: 12),

                // 2. Campo de Correo electrónico
                _AuthInputCard(
                  label: 'Correo electrónico',
                  hintText: 'nombre@correo.com',
                  controller: _email,
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 12),

                // 3. Campo de Contraseña (mínimo 8 caracteres)
                _AuthInputCard(
                  label: 'Contraseña',
                  hintText: 'Mínimo 8 caracteres',
                  controller: _pass,
                  prefixIcon: Icons.lock_open_rounded,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Campo de Confirmar contraseña
                _AuthInputCard(
                  label: 'Confirmar contraseña',
                  hintText: 'Repite tu contraseña',
                  controller: _confirmPass,
                  prefixIcon: Icons.lock_open_rounded,
                  obscureText: _hideConfirmPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _loading ? null : _submit(),
                  suffixIcon: IconButton(
                    tooltip: _hideConfirmPassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () => setState(
                        () => _hideConfirmPassword = !_hideConfirmPassword),
                    icon: Icon(
                      _hideConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Botón primario "Crear cuenta"
                _PrimaryAuthButton(
                  label: 'Crear cuenta',
                  icon: Icons.person_add_outlined,
                  loading: _loading,
                  onPressed: _submit,
                ),

                const Spacer(),
                const SizedBox(height: 24),

                // Nota legal inferior sobre Términos y Política de privacidad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: 'Al crear tu cuenta aceptas los '),
                        TextSpan(
                          text: 'Términos',
                          style: TextStyle(
                            color: Color(0xFF1D4F91),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: ' y la '),
                        TextSpan(
                          text: 'Política\nde privacidad.',
                          style: TextStyle(
                            color: Color(0xFF1D4F91),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BLOQUE 4: ENCABEZADO SUPERIOR DE NAVEGACIÓN
  // Usado en las pantallas de "Olvidé mi contraseña" y "Crea tu cuenta".
  // Muestra el botón circular para regresar y el ícono de PawTrack a la derecha.
  // ==========================================================================
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botón circular para regresar al inicio de sesión
        InkWell(
          onTap: _loading ? null : () => _switchMode(_AuthViewMode.login),
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF0F2B48),
                size: 22,
              ),
            ),
          ),
        ),

        // Mini logo de PawTrack en la esquina superior derecha
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A1E3C).withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BLOQUE 5: COMPONENTE DE TARJETA DE ENTRADA DE TEXTO (_AuthInputCard)
// Dibuja un contenedor con bordes redondeados que agrupa la etiqueta superior
// ("Correo electrónico", "Contraseña", etc.) y el campo de texto debajo.
// ============================================================================
class _AuthInputCard extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool highlightBorder;
  final bool indentWithoutIcon;

  const _AuthInputCard({
    required this.label,
    required this.hintText,
    required this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.highlightBorder = false,
    this.indentWithoutIcon = false,
  });

  @override
  State<_AuthInputCard> createState() => _AuthInputCardState();
}

class _AuthInputCardState extends State<_AuthInputCard> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeBorder = _isFocused || widget.highlightBorder;
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.fromLTRB(
          widget.prefixIcon != null
              ? 14
              : (widget.indentWithoutIcon ? 42 : 16),
          9,
          widget.suffixIcon != null ? 6 : 14,
          9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activeBorder
                ? const Color(0xFF3B6FB6)
                : const Color(0xFFD5DFEC),
            width: activeBorder ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Ícono izquierdo opcional (sobre de correo o candado)
            if (widget.prefixIcon != null) ...[
              Icon(
                widget.prefixIcon,
                color: const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(width: 12),
            ],

            // Columna con la etiqueta pequeña arriba y el campo de texto abajo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textCapitalization: widget.textCapitalization,
                    autofillHints: widget.autofillHints,
                    onSubmitted: widget.onSubmitted,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            // Ícono derecho opcional (ojo para ver/ocultar contraseña)
            if (widget.suffixIcon != null) widget.suffixIcon!,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BLOQUE 6: BOTÓN PRIMARIO DE AUTENTICACIÓN (_PrimaryAuthButton)
// Botón azul oscuro con sombra difuminada e ícono para las acciones principales:
// "Iniciar sesión", "Enviar enlace" y "Crear cuenta".
// ============================================================================
class _PrimaryAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryAuthButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4D8E).withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1B4D8E),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1B4D8E).withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================================
// BLOQUE 7: MARCA DE AGUA DE HUELLA (_PawWatermark)
// Dibuja la silueta suave de una huella canina en el fondo superior derecho
// de la pantalla de inicio de sesión.
// ============================================================================
class _PawWatermark extends StatelessWidget {
  const _PawWatermark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: CustomPaint(
        painter: _PawWatermarkPainter(),
      ),
    );
  }
}

class _PawWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE9F0FA).withOpacity(0.75)
      ..style = PaintingStyle.fill;

    // Almohadilla central grande de la huella
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.48, size.height * 0.66),
        width: 112,
        height: 82,
      ),
      paint,
    );

    // 4 dedos superiores de la huella
    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.34), 21, paint);
    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.16), 22, paint);
    canvas.drawCircle(Offset(size.width * 0.64, size.height * 0.16), 22, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.34), 21, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// BLOQUE 8: ÍCONO MULTICOLOR DE GOOGLE (_GoogleLogoIcon)
// Dibuja la "G" oficial de Google con sus cuatro colores (azul, rojo,
// amarillo y verde) para el botón "Continuar con Google".
// ============================================================================
class _GoogleLogoIcon extends StatelessWidget {
  final double size;
  const _GoogleLogoIcon({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Arco rojo superior
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.35, 1.55, false, paint);

    // Arco amarillo izquierdo
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.55, false, paint);

    // Arco verde inferior
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.80, 1.55, false, paint);

    // Arco azul derecho + barra horizontal de la G
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.15, 0.95, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.40,
        size.width * 0.48,
        stroke * 0.95,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
