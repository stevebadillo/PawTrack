import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

// ============================================================================
// PANTALLA DE NOTIFICACIONES (NotificationsScreen)
// Muestra las alertas de FCM y Firestore en tiempo real sobre:
// 1. Nuevos reportes de incidencia (Personal)
// 2. Cambios de estado en los reportes (Estudiantes y Personal)
// 3. Próximas fechas de vacunación dentro de los próximos 7 días (Personal)
// ============================================================================
class NotificationsScreen extends StatelessWidget {
  final AppUser user;
  const NotificationsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Text(
            'Notificaciones',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B2545),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppNotificationItem>>(
            stream:
                DataService.notifications(user.uid, isStaff: user.isStaff),
            builder: (context, notifSnap) {
              return StreamBuilder<List<Report>>(
                stream: DataService.reports(
                    reporterId: user.isStaff ? null : user.uid),
                builder: (context, reportsSnap) {
                  return StreamBuilder<List<UpcomingVaccineAlert>>(
                    stream: user.isStaff
                        ? DataService.upcomingVaccines(withinDays: 7)
                        : Stream.value(const <UpcomingVaccineAlert>[]),
                    builder: (context, vaccinesSnap) {
                      final notifs = notifSnap.data ?? [];
                      final reports = reportsSnap.data ?? [];
                      final upcomingVaccines = vaccinesSnap.data ?? [];

                      final items = <_NotifData>[];
                      final notifiedVaccineIds = <String>{};

                      // 1. Notificaciones almacenadas en la colección 'notificaciones'
                      for (final n in notifs) {
                        if (n.vaccineId != null) {
                          notifiedVaccineIds.add(n.vaccineId!);
                        }
                        final (icon, color, badge) = switch (n.type) {
                          'nuevo_reporte' => (
                              Icons.warning_amber_rounded,
                              const Color(0xFFDC2626),
                              'Nuevo reporte'
                            ),
                          'cambio_estado' => (
                              Icons.sync_rounded,
                              const Color(0xFF1E5BB0),
                              'Cambio de estado'
                            ),
                          'proxima_vacuna' => (
                              Icons.vaccines_rounded,
                              const Color(0xFF7C3AED),
                              'Vacunación'
                            ),
                          _ => (
                              Icons.notifications_active_outlined,
                              const Color(0xFF1E5BB0),
                              'Aviso'
                            ),
                        };
                        items.add(_NotifData(
                          title: n.title,
                          body: n.body,
                          date: n.createdAt,
                          icon: icon,
                          color: color,
                          badge: badge,
                        ));
                      }

                      // 2. Alertas en tiempo real de próximas fechas de vacunación (Personal)
                      if (user.isStaff) {
                        final fmt = DateFormat('dd/MM/yyyy · HH:mm');
                        for (final v in upcomingVaccines) {
                          if (!notifiedVaccineIds.contains(v.vaccineId)) {
                            items.add(_NotifData(
                              title: 'Próxima vacunación: ${v.dogName}',
                              body:
                                  'Refuerzo de ${v.vaccineName} programado para el ${fmt.format(v.nextDate)}.${v.notes.isNotEmpty ? ' Nota: ${v.notes}' : ''}',
                              date: v.nextDate,
                              icon: Icons.vaccines_rounded,
                              color: const Color(0xFF7C3AED),
                              badge: 'Próxima vacuna',
                            ));
                          }
                        }
                      }

                      // 3. Notificaciones derivadas del estado actual de los reportes
                      final notifiedReportIds = notifs
                          .map((n) => n.reportId)
                          .whereType<String>()
                          .toSet();
                      for (final r in reports) {
                        if (!notifiedReportIds.contains(r.id)) {
                          final dogLabel = r.unidentified
                              ? 'Perro sin identificar'
                              : (r.dogName ?? 'Perro');
                          if (user.isStaff) {
                            if (r.status == 'pendiente') {
                              items.add(_NotifData(
                                title: 'Nueva incidencia: $dogLabel',
                                body:
                                    '${r.reporterName.isNotEmpty ? r.reporterName : "Estudiante"} reportó: "${r.description}"',
                                date: r.createdAt,
                                icon: Icons.warning_amber_rounded,
                                color: const Color(0xFFDC2626),
                                badge: 'Nuevo reporte',
                              ));
                            } else if (r.status == 'en_revision' ||
                                r.status == 'en_atencion') {
                              items.add(_NotifData(
                                title: 'Incidencia en revisión: $dogLabel',
                                body:
                                    'El personal está atendiendo el reporte en el campus.',
                                date: r.createdAt,
                                icon: Icons.access_time_rounded,
                                color: const Color(0xFFB45309),
                                badge: 'Cambio de estado',
                              ));
                            } else {
                              items.add(_NotifData(
                                title: 'Incidencia atendida: $dogLabel',
                                body: r.staffNote.isNotEmpty
                                    ? r.staffNote
                                    : 'Caso resuelto satisfactoriamente.',
                                date: r.createdAt,
                                icon: Icons.check_circle_outline,
                                color: const Color(0xFF15803D),
                                badge: 'Resuelto',
                              ));
                            }
                          } else {
                            if (r.status == 'resuelto') {
                              items.add(_NotifData(
                                title: 'Reporte resuelto',
                                body:
                                    'La atención de $dogLabel ha finalizado satisfactoriamente.',
                                date: r.createdAt,
                                icon: Icons.check_circle_outline,
                                color: const Color(0xFF15803D),
                                badge: 'Cambio de estado',
                              ));
                            } else if (r.status == 'en_revision' ||
                                r.status == 'en_atencion') {
                              items.add(_NotifData(
                                title: 'Reporte en revisión',
                                body:
                                    'El personal está atendiendo la incidencia sobre $dogLabel.',
                                date: r.createdAt,
                                icon: Icons.sync,
                                color: const Color(0xFFB45309),
                                badge: 'Cambio de estado',
                              ));
                            } else {
                              items.add(_NotifData(
                                title: 'Reporte registrado',
                                body:
                                    'Tu reporte de $dogLabel fue recibido correctamente.',
                                date: r.createdAt,
                                icon: Icons.assignment_outlined,
                                color: const Color(0xFF1E5BB0),
                                badge: 'Enviado',
                              ));
                            }
                          }
                        }
                      }

                      items.sort((a, b) => b.date.compareTo(a.date));

                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.notifications_none_rounded,
                                    size: 54, color: Color(0xFF94A3B8)),
                                SizedBox(height: 16),
                                Text(
                                  'No tienes notificaciones',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Color(0xFF0F2B48)),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Aquí recibirás alertas sobre nuevos reportes, cambios de estado y próximas fechas de vacunación.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Color(0xFF64748B), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final it = items[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: it.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(it.icon,
                                      color: it.color, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              it.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: Color(0xFF0F2B48),
                                              ),
                                            ),
                                          ),
                                          if (it.badge.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: it.color
                                                    .withValues(alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                it.badge,
                                                style: TextStyle(
                                                  color: it.color,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        it.body,
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateFormat('dd MMM · HH:mm')
                                            .format(it.date),
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotifData {
  final String title, body, badge;
  final DateTime date;
  final IconData icon;
  final Color color;
  const _NotifData({
    required this.title,
    required this.body,
    required this.date,
    required this.icon,
    required this.color,
    this.badge = '',
  });
}
