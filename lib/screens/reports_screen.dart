import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'dog_detail_screen.dart';
import 'edit_report_screen.dart';

extension StringCapitalize on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}

const statusLabels = {
  'pendiente': 'Pendiente',
  'en_revision': 'En revisión',
  'en_atencion': 'En revisión',
  'resuelto': 'Resuelto'
};

Color statusColor(String s) => s == 'resuelto'
    ? const Color(0xFF15803D)
    : (s == 'en_atencion' || s == 'en_revision'
        ? const Color(0xFFB45309)
        : const Color(0xFFDC2626));

/// Personal: ve y gestiona todos (RF12, RF13). Estudiante: ve los suyos.
class ReportsScreen extends StatelessWidget {
  final AppUser user;
  const ReportsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: DataService.reports(reporterId: user.isStaff ? null : user.uid),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Todo tranquilo por ahora',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                      user.isStaff
                          ? 'Cuando alguien reporte una incidencia, aparecerá aquí.'
                          : 'Tus reportes aparecerán aquí para que puedas seguir su atención.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4)),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            user.isStaff
                                ? 'Incidencias del campus'
                                : 'Mis reportes',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                            '${list.length} ${list.length == 1 ? 'reporte' : 'reportes'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const Icon(Icons.filter_list_rounded),
                ],
              ),
            ),
            for (final r in list)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    builder: (_) => ReportSheet(report: r, user: user),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: reportPhoto(r, width: 76, height: 84),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        r.unidentified
                                            ? 'Sin identificar'
                                            : (r.dogName ?? 'Perro'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800)),
                                  ),
                                  _StatusBadge(status: r.status),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(r.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                      DateFormat('dd/MM · HH:mm')
                                          .format(r.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
                                  if (user.isStaff &&
                                      r.reporterName.isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    const Icon(Icons.person_outline, size: 14),
                                    const SizedBox(width: 3),
                                    Expanded(
                                        child: Text(r.reporterName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(statusLabels[status] ?? status,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class ReportSheet extends StatefulWidget {
  final Report report;
  final AppUser user;
  const ReportSheet({super.key, required this.report, required this.user});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  late final TextEditingController _noteController;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.report.staffNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _editDescription(Report report) async {
    final controller = TextEditingController(text: report.description);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar reporte'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await DataService.updateReportDescription(report.id, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte actualizado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo editar el reporte: $e')),
        );
      }
    }
  }

  Future<void> _saveNote(Report report) async {
    setState(() => _savingNote = true);
    try {
      await DataService.updateReportStaffNote(
          report.id, _noteController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota guardada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la nota: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _deleteReport(Report report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content:
            const Text('Esta acción eliminará el reporte permanentemente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataService.deleteReport(report.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el reporte: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final user = widget.user;
    final isResolved = r.status == 'resuelto';
    final isInReview = r.status == 'en_revision' || r.status == 'en_atencion';
    final isPending = r.status == 'pendiente';
    final hasPhoto = r.photoBase64.isNotEmpty || r.photoUrl.isNotEmpty;
    final latLng = LatLng(r.lat != 0 ? r.lat : -1.65595, r.lng != 0 ? r.lng : -78.67508);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Icon(Icons.chevron_left_rounded, color: Color(0xFF0F2B48), size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Detalle del reporte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2B48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Status Banner
            if (isResolved)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB7E4C7)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle_outline, color: Color(0xFF15803D), size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Resuelto',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Este reporte ya fue atendido. Aquí ves cómo se resolvió.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (isInReview)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.access_time_rounded, color: Color(0xFFB45309), size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'En revisión',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'El personal está revisando tu reporte. Ya no se puede editar.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE4E6),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Pendiente',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Puedes editar tu reporte hasta que el personal empiece a revisarlo.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF881337),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Si está resuelto: Sección "Cómo se resolvió"
            if (isResolved) ...[
              const Text(
                'Cómo se resolvió',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCIONES REALIZADAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.staffNote.isNotEmpty
                          ? r.staffNote
                          : 'El personal atendió la incidencia en el campus y el perro se encuentra en buen estado.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Atendido el', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        Text(
                          DateFormat('dd/MM · HH:mm').format(r.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F2B48)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sección "Perro" con enlace a Ficha del perro
              const Text(
                'Perro',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: r.dogId != null
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DogDetailScreen(dogId: r.dogId!, user: user)),
                        )
                    : null,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFFF1F5FD),
                          child: const Icon(Icons.pets, color: Color(0xFF1E5BB0), size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.dogName?.isNotEmpty == true ? r.dogName! : 'Rodolfo',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF0B2545),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.dogId != null ? 'Ver ficha del perro' : 'Perro comunitario',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E5BB0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (r.dogId != null)
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Evidencia
            const Text(
              'Evidencia',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
            ),
            const SizedBox(height: 10),
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: reportPhoto(r),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Sin fotos adjuntas',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Detalles
            const Text(
              'Detalles',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _detailRow(
                    'Estado del perro',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                        const SizedBox(width: 6),
                        Text(
                          r.dogStatus.isNotEmpty
                              ? r.dogStatus.replaceAll('_', ' ').capitalize()
                              : 'Con vida',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _detailRow(
                    'Tipo de incidencia',
                    Text(
                      r.incidentType.isNotEmpty ? r.incidentType.capitalize() : 'Otro',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48)),
                    ),
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _detailRow(
                    'Perro relacionado',
                    Text(
                      r.unidentified ? 'Sin identificar' : (r.dogName ?? 'Sin identificar'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48)),
                    ),
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _detailRow(
                    'Fecha',
                    Text(
                      DateFormat('dd/MM · HH:mm').format(r.createdAt),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48)),
                    ),
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _detailRow(
                    'Reportado por',
                    Text(
                      r.reporterName.isNotEmpty ? r.reporterName : 'steve',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Descripción
            const Text(
              'Descripción',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                r.description.isNotEmpty ? r.description : 'Cachorros bajo una banca',
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.35),
              ),
            ),
            const SizedBox(height: 20),

            // Ubicación
            const Text(
              'Ubicación',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    SizedBox(
                      height: 160,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: latLng,
                          initialZoom: 16.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'ec.edu.espoch.pawtrack',
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: latLng,
                                radius: 32,
                                color: const Color(0xFF1E5BB0).withOpacity(0.18),
                                borderColor: const Color(0xFF1E5BB0),
                                borderStrokeWidth: 1.5,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: latLng,
                                width: 36,
                                height: 36,
                                child: const Icon(Icons.location_on, color: Color(0xFFF97316), size: 36),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D3B73),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ubicación adjunta',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F2B48)),
                                ),
                                Text(
                                  '${r.lat.toStringAsFixed(5)}, ${r.lng.toStringAsFixed(5)}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botón editar si está pendiente
            if (isPending || user.isStaff) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B73),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditReportScreen(report: r, user: user)),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar reporte', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],

            // Panel de gestión para personal
            if (user.isStaff) ...[
              const Divider(height: 36),
              const Text('Gestión del personal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nota de resolución / Acciones tomadas',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _savingNote ? null : () => _saveNote(r),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar acciones'),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Cambiar estado:'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in reportStatuses)
                    ChoiceChip(
                      label: Text(statusLabels[s] ?? s),
                      selected: r.status == s,
                      onSelected: (_) async {
                        await DataService.updateReportStatus(r.id, s);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _deleteReport(r),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar reporte'),
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
        value,
      ],
    );
  }
}

Widget _reportImage(String url, {double? width, double? height}) {
  if (url.isEmpty) return _missingImage(width: width, height: height);
  return Image.network(
    url,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => _missingImage(width: width, height: height),
  );
}

Widget reportPhoto(Report report, {double? width, double? height}) {
  if (report.photoBase64.isNotEmpty) {
    try {
      return Image.memory(
        base64Decode(report.photoBase64),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _missingImage(width: width, height: height),
      );
    } catch (_) {
      return _missingImage(width: width, height: height);
    }
  }
  return _reportImage(report.photoUrl, width: width, height: height);
}

Widget _missingImage({double? width, double? height}) => Container(
      width: width,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
