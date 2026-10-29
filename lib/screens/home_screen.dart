import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'dogs_screen.dart';
import 'reports_screen.dart';
import 'map_screen.dart';
import 'report_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final Stream<AppUser> _user = AuthService.currentUser();

  void _createReport(AppUser user) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReportFormScreen(user: user)),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 380;
    return StreamBuilder<AppUser>(
      stream: _user,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 48, color: colors.error),
                    const SizedBox(height: 16),
                    const Text('No pudimos cargar tu perfil',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'Comprueba tu conexión y vuelve a iniciar sesión.'),
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
        if (!snap.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
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
        ];
        return Scaffold(
          appBar: AppBar(
            titleSpacing: compact ? 8 : 16,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: compact ? 34 : 38,
                    height: compact ? 34 : 38,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: compact ? 7 : 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('PawTrack',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 16 : 18)),
  
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (compact)
                Tooltip(
                  message: user.isStaff ? 'Personal' : 'Estudiante',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      user.isStaff
                          ? Icons.admin_panel_settings_outlined
                          : Icons.school_outlined,
                      size: 21,
                      color: colors.primary,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Chip(
                    avatar: Icon(
                        user.isStaff
                            ? Icons.admin_panel_settings_outlined
                            : Icons.school_outlined,
                        size: 17),
                    label: Text(user.isStaff ? 'Personal' : 'Estudiante'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: AuthService.logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: IndexedStack(index: _tab, children: pages),
            ),
          ),
          floatingActionButton: _tab == 0
              ? null
              : compact
                  ? FloatingActionButton(
                      tooltip: 'Crear reporte',
                      onPressed: () => _createReport(user),
                      child: const Icon(Icons.add_a_photo_outlined),
                    )
                  : FloatingActionButton.extended(
                      onPressed: () => _createReport(user),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Reportar'),
                    ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: 'Inicio'),
              NavigationDestination(
                  icon: Icon(Icons.pets_outlined),
                  selectedIcon: Icon(Icons.pets),
                  label: 'Perros'),
              NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: 'Reportes'),
              NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Mapa'),
            ],
          ),
        );
      },
    );
  }
}
