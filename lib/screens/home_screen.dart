import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'dogs_screen.dart';
import 'reports_screen.dart';
import 'map_screen.dart';
import 'report_form_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'pawbot_screen.dart';

// ============================================================================
// PANTALLA CONTENEDORA PRINCIPAL (HomeScreen)
// Gestiona el menú lateral (Drawer), la barra superior con el rol del usuario
// y la navegación entre las pestañas de Inicio, Perros, Reportes, Mapa,
// Notificaciones y Configuraciones.
// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Índice de la pestaña activa actualmente
  int _tab = 0;
  // Flujo con los datos del usuario autenticado
  late final Stream<AppUser> _user = AuthService.currentUser();

  // Abre el formulario para crear un nuevo reporte de incidencia
  void _createReport(AppUser user) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReportFormScreen(user: user)),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: _user,
      builder: (context, snap) {
        if (snap.hasError) {
          final missingProfile = snap.error is UserProfileMissingException;
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 48, color: Color(0xFFDC2626)),
                    const SizedBox(height: 16),
                    const Text('No pudimos cargar tu perfil',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(missingProfile
                        ? 'No encontramos tu perfil en usuarios ni en la colección anterior. Si fue eliminado por error, pídele al administrador que lo restaure.'
                        : 'Comprueba tu conexión y vuelve a iniciar sesión.'),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                        onPressed: AuthService.logout,
                        child: const Text('Cerrar sesión')),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data!;
        final pages = [
          DashboardScreen(
            user: user,
            onOpenTab: (index) => setState(() => _tab = index),
            onNewReport: () => _createReport(user),
          ),
          DogsScreen(user: user),
          ReportsScreen(user: user),
          MapScreen(user: user),
          NotificationsScreen(user: user),
          SettingsScreen(user: user),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FF),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(66),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Builder(
                  builder: (scaffoldContext) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botón izquierdo de menú hamburguesa -> Abre el menú lateral (Drawer)
                        InkWell(
                          onTap: () =>
                              Scaffold.of(scaffoldContext).openDrawer(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.menu_rounded,
                                color: Color(0xFF0F2B48),
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        // Etiqueta central con el rol del usuario (Estudiante o Personal)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.isStaff ? 'Personal' : 'Estudiante',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F2B48),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_user_outlined,
                                size: 16,
                                color: Color(0xFF1E5BB0),
                              ),
                            ],
                          ),
                        ),

                        // Botón circular derecho con huella -> Regresa directamente al Inicio
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_tab != 0) {
                              setState(() => _tab = 0);
                            }
                          },
                          child: Tooltip(
                            message: 'Ir al inicio',
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0D3B73),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.pets,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF97316),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          drawer: Drawer(
            backgroundColor: const Color(0xFFF4F7FC),
            elevation: 0,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Inicio
                  _DrawerItem(
                    title: 'Inicio',
                    icon: Icons.home_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isActive: _tab == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _tab = 0);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Reportes
                  _DrawerItem(
                    title: 'Reportes',
                    icon: Icons.assignment_outlined,
                    isActive: _tab == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _tab = 2);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Perros
                  _DrawerItem(
                    title: 'Perros',
                    icon: Icons.pets,
                    isActive: _tab == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _tab = 1);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Notificaciones
                  _DrawerItem(
                    title: 'Notificaciones',
                    icon: Icons.notifications_none_rounded,
                    isActive: _tab == 4,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _tab = 4);
                    },
                  ),
                  const SizedBox(height: 8),
                  // PawBot (Asistente Virtual Inteligente)
                  _DrawerItem(
                    title: 'Asistente PawBot',
                    icon: Icons.smart_toy_outlined,
                    iconColor: const Color(0xFF1E5BB0),
                    isActive: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PawBotScreen(user: user)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Configuraciones
                  _DrawerItem(
                    title: 'Configuraciones',
                    icon: Icons.settings_outlined,
                    isActive: _tab == 5,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _tab = 5);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Salir
                  _DrawerItem(
                    title: 'Salir',
                    icon: Icons.logout_rounded,
                    isActive: false,
                    onTap: () {
                      Navigator.pop(context);
                      AuthService.logout();
                    },
                  ),
                ],
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: IndexedStack(index: _tab, children: pages),
            ),
          ),
          floatingActionButton: _tab == 0
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PawBotScreen(user: user)),
                  ),
                  backgroundColor: const Color(0xFF0D3B73),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.pets_rounded, size: 20),
                  label: const Text(
                    'PawBot',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return Padding(
        padding: const EdgeInsets.only(right: 28),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B3A6F),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(28)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, color: iconColor ?? Colors.white, size: 22),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF0B3A6F), size: 22),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0B3A6F),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
