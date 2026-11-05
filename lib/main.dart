import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

// ============================================================================
// PUNTO DE ENTRADA PRINCIPAL DE LA APLICACIÓN
// Inicializa los servicios de Flutter y conecta la app con Firebase antes
// de lanzar la interfaz gráfica principal (PawTrackApp).
// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PawTrackApp());
}

// ============================================================================
// WIDGET RAÍZ DE PAWTRACK
// Configura el tema visual global (colores, campos de texto, tarjetas, barra
// de navegación) y escucha el estado de autenticación del usuario.
// ============================================================================
class PawTrackApp extends StatelessWidget {
  const PawTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawTrack',
      debugShowCheckedModeBanner: false,

      // ----------------------------------------------------------------------
      // CONFIGURACIÓN DEL TEMA VISUAL (MATERIAL 3)
      // Define la paleta de colores azul institucional de PawTrack y los
      // estilos predeterminados para formularios, tarjetas y alertas.
      // ----------------------------------------------------------------------
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2A5FC4),
          secondary: const Color(0xFFE8521A),
          surface: const Color(0xFFF4F7FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7FF),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD0DBF5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2A5FC4), width: 1.5),
          ),
        ),
        cardColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFD0DBF5)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: const Color(0xFFF4F7FF),
          indicatorColor: const Color(0xFFD0E0FF),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              )),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        dividerColor: const Color(0xFFD0DBF5),
        useMaterial3: true,
      ),
      // ----------------------------------------------------------------------
      // CONTROL DE SESIÓN EN TIEMPO REAL
      // Si el usuario no ha iniciado sesión muestra LoginScreen; si ya tiene
      // sesión activa, inicializa notificaciones y abre HomeScreen.
      // ----------------------------------------------------------------------
      home: SplashScreen(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (snap.data == null) return const LoginScreen();
            NotificationService.init(snap.data!.uid);
            return const HomeScreen();
          },
        ),
      ),
    );
  }
}
