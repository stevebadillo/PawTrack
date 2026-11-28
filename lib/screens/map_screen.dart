import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';
import 'reports_screen.dart';

// ============================================================================
// PANTALLA DE MAPA DE INCIDENCIAS (MapScreen)
// Muestra el mapa interactivo del campus de la ESPOCH con marcadores de color
// según el estado de cada reporte y una tarjeta inferior con el detalle.
// ============================================================================
class MapScreen extends StatefulWidget {
  final AppUser user;
  const MapScreen({super.key, required this.user});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Coordenadas centrales del campus politécnico ESPOCH en Riobamba
  static const _espoch = LatLng(-1.6545, -78.6775);
  final MapController _mapController = MapController();

  Report? _selectedReport;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // Obtiene la ubicación actual del dispositivo para mostrarla en el mapa
  Future<void> _getUserLocation() async {
    try {
      final pos = await LocationService.current();
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  // Centra la vista del mapa en la ubicación del usuario o en la ESPOCH
  void _recenter() {
    final target = _userLocation ?? _espoch;
    _mapController.move(target, 16.5);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: DataService.reports(reporterId: widget.user.isStaff ? null : widget.user.uid),
      builder: (context, snap) {
        final reports = snap.data ?? <Report>[];

        // Si aún no hay un reporte seleccionado, selecciona el más reciente por defecto
        if (_selectedReport == null && reports.isNotEmpty) {
          _selectedReport = reports.first;
        }

        return Column(
          children: [
            // Bloque 1: Encabezado superior del mapa
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Mapa de incidencias',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                ],
              ),
            ),

            // Bloque 2: Mapa interactivo y tarjeta flotante inferior
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: _espoch,
                      initialZoom: 16.5,
                      maxZoom: 19,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ec.edu.espoch.pawtrack',
                        maxNativeZoom: 19,
                      ),

                      // User Location Blue Pulse
                      if (_userLocation != null) ...[
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _userLocation!,
                              radius: 28,
                              color: const Color(0xFF1E5BB0).withValues(alpha: 0.2),
                              borderColor: const Color(0xFF1E5BB0),
                              borderStrokeWidth: 1.5,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userLocation!,
                              width: 22,
                              height: 22,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D3B73),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Report Markers
                      MarkerLayer(
                        markers: [
                          for (final r in reports)
                            Marker(
                              point: LatLng(r.lat, r.lng),
                              width: 44,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedReport = r);
                                  _mapController.move(LatLng(r.lat, r.lng), 17);
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_selectedReport?.id == r.id)
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF97316).withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Icon(
                                      Icons.location_on,
                                      size: 38,
                                      color: _getPinColor(r.status),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Re-center button
                  Positioned(
                    right: 16,
                    bottom: _selectedReport != null ? 180 : 20,
                    child: InkWell(
                      onTap: _recenter,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.my_location, color: Color(0xFF0F2B48), size: 20),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Floating Card
                  if (_selectedReport != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Handle bar
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Selected report info row
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5FD),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.pets, color: Color(0xFF1E5BB0), size: 18),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedReport!.unidentified
                                            ? 'Sin identificar'
                                            : (_selectedReport!.dogName?.isNotEmpty == true
                                                ? _selectedReport!.dogName!
                                                : 'Sin identificar'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFF0B2545),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        DateFormat('dd MMM · HH:mm').format(_selectedReport!.createdAt),
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(_selectedReport!.status),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Button "Ver reporte"
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D3B73),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                    builder: (_) => ReportSheet(report: _selectedReport!, user: widget.user),
                                  );
                                },
                                child: const Text(
                                  'Ver reporte',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getPinColor(String status) {
    if (status == 'resuelto') return const Color(0xFF10B981);
    if (status == 'en_revision' || status == 'en_atencion') return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  Widget _buildStatusBadge(String status) {
    final isResolved = status == 'resuelto';
    final isInReview = status == 'en_revision' || status == 'en_atencion';

    final pillBg = isResolved
        ? const Color(0xFFEAF8F0)
        : (isInReview ? const Color(0xFFFEF5E7) : const Color(0xFFFEF2F2));
    final pillColor = isResolved
        ? const Color(0xFF15803D)
        : (isInReview ? const Color(0xFFB45309) : const Color(0xFFDC2626));
    final pillText = isResolved
        ? 'Resuelto'
        : (isInReview ? 'En revisión' : 'Pendiente');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: pillColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            pillText,
            style: TextStyle(
              color: pillColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
