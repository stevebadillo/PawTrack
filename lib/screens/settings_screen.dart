import 'package:flutter/material.dart';
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
        const Text(
          'Configuraciones',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0B2545),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF0F3E7D),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F2B48)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.isStaff ? 'Personal ESPOCH' : 'Estudiante',
                        style: const TextStyle(
                          color: Color(0xFF1E5BB0),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'General',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: Color(0xFF0F3E7D)),
                title: const Text('Notificaciones push'),
                subtitle: const Text('Recibir avisos de estado de reportes'),
                trailing: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Color(0xFF0F3E7D)),
                title: const Text('Permiso de GPS'),
                subtitle: const Text('Ubicación precisa para reportes'),
                trailing: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Color(0xFF0F3E7D)),
                title: const Text('Acerca de PawTrack'),
                subtitle: const Text('Versión 1.0.0 · ESPOCH'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: AuthService.logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
