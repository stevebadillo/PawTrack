import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'reports_screen.dart';

/// Incidencias sobre OpenStreetMap (RF14).
class MapScreen extends StatelessWidget {
  final AppUser user;
  const MapScreen({super.key, required this.user});

  static const _espoch = LatLng(-1.6545, -78.6775); // Campus ESPOCH, Riobamba

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: DataService.reports(reporterId: user.isStaff ? null : user.uid),
      builder: (context, snap) {
        final reports = snap.data ?? <Report>[];
        return FlutterMap(
          options: const MapOptions(
              initialCenter: _espoch, initialZoom: 16, maxZoom: 19),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ec.edu.espoch.pawtrack',
              maxNativeZoom: 19,
            ),
            MarkerLayer(markers: [
              for (final r in reports)
                Marker(
                  point: LatLng(r.lat, r.lng),
                  width: 44,
                  height: 52,
                  child: Tooltip(
                    message:
                        '${r.unidentified ? 'Sin identificar' : (r.dogName ?? 'Perro')} · ${statusLabels[r.status] ?? r.status}',
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.location_on,
                          size: 42, color: statusColor(r.status)),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => ReportSheet(report: r, user: user),
                      ),
                    ),
                  ),
                ),
            ]),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text('© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 11)),
                  ),
                ),
              ),
            ),
            if (snap.hasError)
              Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                        'No se pudieron cargar los reportes: ${snap.error}'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
