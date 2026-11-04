import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

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
            stream: DataService.notifications(user.uid),
            builder: (context, notifSnap) {
              return StreamBuilder<List<Report>>(
                stream: DataService.reports(reporterId: user.isStaff ? null : user.uid),
                builder: (context, reportsSnap) {
                  final notifs = notifSnap.data ?? [];
                  final reports = reportsSnap.data ?? [];

                  final items = <_NotifData>[];
                  for (final n in notifs) {
                    items.add(_NotifData(
                      title: n.title,
                      body: n.body,
                      date: n.createdAt,
                      icon: Icons.notifications_active_outlined,
                      color: const Color(0xFF1E5BB0),
                    ));
                  }

                  if (items.isEmpty) {
                    for (final r in reports) {
                      final dogLabel = r.unidentified ? 'Perro sin identificar' : (r.dogName ?? 'Perro');
                      if (user.isStaff) {
                        if (r.status == 'pendiente') {
                          items.add(_NotifData(
                            title: 'Nueva incidencia: $dogLabel',
                            body: '${r.reporterName.isNotEmpty ? r.reporterName : "Estudiante"} reportó: "${r.description}"',
                            date: r.createdAt,
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFDC2626),
                          ));
                        } else if (r.status == 'en_revision' || r.status == 'en_atencion') {
                          items.add(_NotifData(
                            title: 'Incidencia en revisión: $dogLabel',
                            body: 'El personal está atendiendo el reporte en el campus.',
                            date: r.createdAt,
                            icon: Icons.access_time_rounded,
                            color: const Color(0xFFB45309),
                          ));
                        } else {
                          items.add(_NotifData(
                            title: 'Incidencia atendida: $dogLabel',
                            body: r.staffNote.isNotEmpty ? r.staffNote : 'Caso resuelto satisfactoriamente.',
                            date: r.createdAt,
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF15803D),
                          ));
                        }
                      } else {
                        if (r.status == 'resuelto') {
                          items.add(_NotifData(
                            title: 'Reporte resuelto',
                            body: 'La atención de $dogLabel ha finalizado satisfactoriamente.',
                            date: r.createdAt,
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF15803D),
                          ));
                        } else if (r.status == 'en_revision' || r.status == 'en_atencion') {
                          items.add(_NotifData(
                            title: 'Reporte en revisión',
                            body: 'El personal está atendiendo la incidencia sobre $dogLabel.',
                            date: r.createdAt,
                            icon: Icons.sync,
                            color: const Color(0xFFB45309),
                          ));
                        } else {
                          items.add(_NotifData(
                            title: 'Reporte registrado',
                            body: 'Tu reporte de $dogLabel fue recibido correctamente.',
                            date: r.createdAt,
                            icon: Icons.assignment_outlined,
                            color: const Color(0xFF1E5BB0),
                          ));
                        }
                      }
                    }
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.notifications_none_rounded, size: 54, color: Color(0xFF94A3B8)),
                            SizedBox(height: 16),
                            Text(
                              'No tienes notificaciones',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F2B48)),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Aquí recibirás alertas sobre el estado de tus reportes y campañas del campus.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: it.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(it.icon, color: it.color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF0F2B48),
                                    ),
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
                                    DateFormat('dd MMM · HH:mm').format(it.date),
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
          ),
        ),
      ],
    );
  }
}

class _NotifData {
  final String title, body;
  final DateTime date;
  final IconData icon;
  final Color color;
  const _NotifData({
    required this.title,
    required this.body,
    required this.date,
    required this.icon,
    required this.color,
  });
}
