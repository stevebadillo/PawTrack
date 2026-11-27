import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../widgets/breed_analysis_card.dart';
import 'dog_detail_screen.dart';
import 'edit_report_screen.dart';
import 'report_form_screen.dart';

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

// ============================================================================
// PANTALLA DE LISTADO Y FILTRADO DE REPORTES (ReportsScreen)
// Permite visualizar las incidencias reportadas en el campus, filtrarlas por
// estado, tipo o fecha, y abrir la hoja de detalle de cada reporte.
// ============================================================================
class ReportsScreen extends StatefulWidget {
  final AppUser user;
  const ReportsScreen({super.key, required this.user});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Variables de estado para los filtros de búsqueda
  String? _statusFilter; // null = Todos, 'pendiente', 'en_revision', 'resuelto'
  String? _incidentTypeFilter; // 'perdido', 'agresivo', 'otro'
  String? _datePreset; // 'hoy', 'semana', 'mes'
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Abre la ventana emergente de filtros avanzados
  void _openFilterModal() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterModal(
        initialStatus: _statusFilter,
        initialType: _incidentTypeFilter,
        initialDatePreset: _datePreset,
        initialFrom: _dateFrom,
        initialTo: _dateTo,
      ),
    );

    if (result != null) {
      setState(() {
        _statusFilter = result['status'];
        _incidentTypeFilter = result['type'];
        _datePreset = result['preset'];
        _dateFrom = result['from'];
        _dateTo = result['to'];
      });
    }
  }

  // Filtra la lista de reportes según el estado, tipo de incidencia y rango de fechas
  List<Report> _applyFilters(List<Report> list) {
    return list.where((r) {
      // Filtro por estado del reporte
      if (_statusFilter != null) {
        if (_statusFilter == 'en_revision') {
          if (r.status != 'en_revision' && r.status != 'en_atencion') return false;
        } else if (r.status != _statusFilter) {
          return false;
        }
      }

      // Filtro por tipo de incidencia
      if (_incidentTypeFilter != null && _incidentTypeFilter!.isNotEmpty) {
        if (r.incidentType.toLowerCase() != _incidentTypeFilter!.toLowerCase()) {
          return false;
        }
      }

      // Filtro rápido por fecha (Hoy, Última semana, Último mes)
      final now = DateTime.now();
      if (_datePreset == 'hoy') {
        final startOfToday = DateTime(now.year, now.month, now.day);
        if (r.createdAt.isBefore(startOfToday)) return false;
      } else if (_datePreset == 'semana') {
        final weekAgo = now.subtract(const Duration(days: 7));
        if (r.createdAt.isBefore(weekAgo)) return false;
      } else if (_datePreset == 'mes') {
        final monthAgo = now.subtract(const Duration(days: 30));
        if (r.createdAt.isBefore(monthAgo)) return false;
      }

      // Filtro por rango de fechas personalizado (Desde / Hasta)
      if (_dateFrom != null && r.createdAt.isBefore(_dateFrom!)) return false;
      if (_dateTo != null) {
        final endOfTo = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
        if (r.createdAt.isAfter(endOfTo)) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Report>>(
        stream: DataService.reports(reporterId: widget.user.isStaff ? null : widget.user.uid),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final allReports = snap.data!;
          final filteredReports = _applyFilters(allReports);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
                children: [
                  // Title row
                  const Text(
                    'Reportes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Horizontal Filter Segment Bar (Images 1 & 2)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 1. Todos
                        _buildFilterPill(
                          label: 'Todos',
                          icon: Icons.grid_view_rounded,
                          isSelected: _statusFilter == null,
                          onTap: () => setState(() => _statusFilter = null),
                        ),
                        const SizedBox(width: 8),

                        // 2. Pendiente
                        _buildFilterPill(
                          label: 'Pendiente',
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFDC2626),
                          isSelected: _statusFilter == 'pendiente',
                          activeBgColor: const Color(0xFFFEF2F2),
                          activeTextColor: const Color(0xFFDC2626),
                          onTap: () => setState(() {
                            _statusFilter = _statusFilter == 'pendiente' ? null : 'pendiente';
                          }),
                        ),
                        const SizedBox(width: 8),

                        // 3. En revisión
                        _buildFilterPill(
                          label: 'En revisión',
                          icon: Icons.access_time_rounded,
                          iconColor: const Color(0xFFB45309),
                          isSelected: _statusFilter == 'en_revision',
                          activeBgColor: const Color(0xFFFEF5E7),
                          activeTextColor: const Color(0xFFB45309),
                          onTap: () => setState(() {
                            _statusFilter = _statusFilter == 'en_revision' ? null : 'en_revision';
                          }),
                        ),
                        const SizedBox(width: 8),

                        // 4. Resuelto
                        _buildFilterPill(
                          label: 'Resuelto',
                          icon: Icons.check_rounded,
                          iconColor: const Color(0xFF15803D),
                          isSelected: _statusFilter == 'resuelto',
                          activeBgColor: const Color(0xFFEAF8F0),
                          activeTextColor: const Color(0xFF15803D),
                          onTap: () => setState(() {
                            _statusFilter = _statusFilter == 'resuelto' ? null : 'resuelto';
                          }),
                        ),
                        const SizedBox(width: 8),

                        // 5. Sliders Modal Button
                        InkWell(
                          onTap: _openFilterModal,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (_incidentTypeFilter != null || _datePreset != null || _dateFrom != null)
                                  ? const Color(0xFF0D3B73)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (_incidentTypeFilter != null || _datePreset != null || _dateFrom != null)
                                    ? const Color(0xFF0D3B73)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.tune_rounded,
                                color: (_incidentTypeFilter != null || _datePreset != null || _dateFrom != null)
                                    ? Colors.white
                                    : const Color(0xFF0D3B73),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Report Items
                  if (filteredReports.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron reportes',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0B2545)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusFilter != null
                                  ? 'No hay incidencias con el filtro seleccionado.'
                                  : 'No hay reportes registrados por el momento.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final r in filteredReports)
                      _buildReportCard(r),
                ],
              ),

              // Floating Action Button "Reportar"
              Positioned(
                right: 20,
                bottom: 24,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B73),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    elevation: 4,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportFormScreen(user: widget.user)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 19),
                  label: const Text(
                    'Reportar',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool isSelected,
    Color? activeBgColor,
    Color? activeTextColor,
    required VoidCallback onTap,
  }) {
    if (isSelected) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: activeBgColor ?? const Color(0xFF0D3B73),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activeTextColor ?? const Color(0xFF0D3B73),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: activeTextColor ?? Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeTextColor ?? Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unselected icon button
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Icon(icon, color: iconColor ?? const Color(0xFF64748B), size: 20),
        ),
      ),
    );
  }

  Widget _buildReportCard(Report r) {
    final hasPhoto = r.photoBase64.isNotEmpty || r.photoUrl.isNotEmpty;
    final title = r.unidentified
        ? 'Sin identificar'
        : (r.dogName?.isNotEmpty == true ? r.dogName! : 'Sin identificar');

    final status = r.status;
    final isResolved = status == 'resuelto';
    final isInReview = status == 'en_revision' || status == 'en_atencion';

    final pillBg = isResolved
        ? const Color(0xFFEAF8F0)
        : (isInReview ? const Color(0xFFFEF5E7) : const Color(0xFFFEF2F2));
    final pillColor = isResolved
        ? const Color(0xFF15803D)
        : (isInReview ? const Color(0xFFB45309) : const Color(0xFFDC2626));
    final pillIcon = isResolved
        ? Icons.check
        : (isInReview ? Icons.access_time_rounded : Icons.warning_amber_rounded);
    final pillText = isResolved
        ? 'Resuelto'
        : (isInReview ? 'En revisión' : 'Pendiente');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            builder: (_) => ReportSheet(report: r, user: widget.user),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail or Paw box
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: hasPhoto
                        ? reportPhoto(r, width: 72, height: 72)
                        : Container(
                            color: const Color(0xFFF1F5FD),
                            child: const Center(
                              child: Icon(Icons.pets, color: Color(0xFF93C5FD), size: 26),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF0B2545),
                              ),
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(pillIcon, size: 12, color: pillColor),
                                const SizedBox(width: 4),
                                Text(
                                  pillText,
                                  style: TextStyle(
                                    color: pillColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        r.description.isNotEmpty ? r.description : 'Incidencia canina reportada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM · HH:mm').format(r.createdAt),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                          if (r.reporterName.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.person_outline, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 3),
                            Text(
                              r.reporterName.split(' ').first.toLowerCase(),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
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
    );
  }
}

// -------------------------------------------------------------
// MODAL - FILTROS (Image 3)
// -------------------------------------------------------------
class _FilterModal extends StatefulWidget {
  final String? initialStatus;
  final String? initialType;
  final String? initialDatePreset;
  final DateTime? initialFrom;
  final DateTime? initialTo;

  const _FilterModal({
    this.initialStatus,
    this.initialType,
    this.initialDatePreset,
    this.initialFrom,
    this.initialTo,
  });

  @override
  State<_FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<_FilterModal> {
  late String? _status;
  late String? _type;
  late String? _preset;
  late DateTime? _from;
  late DateTime? _to;

  final _fmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _type = widget.initialType;
    _preset = widget.initialDatePreset;
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  void _clear() {
    setState(() {
      _status = null;
      _type = null;
      _preset = null;
      _from = null;
      _to = null;
    });
  }

  void _apply() {
    Navigator.pop(context, {
      'status': _status,
      'type': _type,
      'preset': _preset,
      'from': _from,
      'to': _to,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  TextButton(
                    onPressed: _clear,
                    child: const Text(
                      'Limpiar',
                      style: TextStyle(
                        color: Color(0xFF1E5BB0),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Estado
              const Text('Estado', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0B2545))),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('Pendiente', _status == 'pendiente', () => setState(() => _status = _status == 'pendiente' ? null : 'pendiente')),
                  const SizedBox(width: 8),
                  _chip('En revisión', _status == 'en_revision', () => setState(() => _status = _status == 'en_revision' ? null : 'en_revision')),
                  const SizedBox(width: 8),
                  _chip('Resueltos', _status == 'resuelto', () => setState(() => _status = _status == 'resuelto' ? null : 'resuelto')),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Tipo de incidencia
              const Text('Tipo de incidencia', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0B2545))),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('Perdido', _type == 'perdido', () => setState(() => _type = _type == 'perdido' ? null : 'perdido')),
                  const SizedBox(width: 8),
                  _chip('Agresivo', _type == 'agresivo', () => setState(() => _type = _type == 'agresivo' ? null : 'agresivo')),
                  const SizedBox(width: 8),
                  _chip('Otro', _type == 'otro', () => setState(() => _type = _type == 'otro' ? null : 'otro')),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Fecha
              const Text('Fecha', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0B2545))),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('Hoy', _preset == 'hoy', () => setState(() => _preset = _preset == 'hoy' ? null : 'hoy')),
                  const SizedBox(width: 8),
                  _chip('Última semana', _preset == 'semana', () => setState(() => _preset = _preset == 'semana' ? null : 'semana')),
                  const SizedBox(width: 8),
                  _chip('Último mes', _preset == 'mes', () => setState(() => _preset = _preset == 'mes' ? null : 'mes')),
                ],
              ),
              const SizedBox(height: 14),

              // Manual date inputs
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _from ?? DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _from = d);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Desde', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                Text(
                                  _from != null ? _fmt.format(_from!) : 'dd/mm/aaaa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _from != null ? const Color(0xFF0B2545) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _to ?? DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setState(() => _to = d);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hasta', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                Text(
                                  _to != null ? _fmt.format(_to!) : 'dd/mm/aaaa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _to != null ? const Color(0xFF0B2545) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Button Aplicar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B73),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: _apply,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Aplicar filtros', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D3B73) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D3B73) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, color: Colors.white, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0B2545),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// MODAL - CAMBIAR ESTADO (Image 5)
// -------------------------------------------------------------
class _ChangeStatusModal extends StatefulWidget {
  final String currentStatus;
  const _ChangeStatusModal({required this.currentStatus});

  @override
  State<_ChangeStatusModal> createState() => _ChangeStatusModalState();
}

class _ChangeStatusModalState extends State<_ChangeStatusModal> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'key': 'pendiente',
        'title': 'Pendiente',
        'subtitle': 'Aún no se ha revisado',
        'color': const Color(0xFFDC2626),
      },
      {
        'key': 'en_revision',
        'title': 'En revisión',
        'subtitle': 'El personal lo está revisando',
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'resuelto',
        'title': 'Atendida',
        'subtitle': 'Ya se atendió al perro',
        'color': const Color(0xFF10B981),
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cambiar estado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0B2545)),
            ),
            const SizedBox(height: 16),
            for (final opt in options)
              _buildOption(
                key: opt['key'] as String,
                title: opt['title'] as String,
                subtitle: opt['subtitle'] as String,
                dotColor: opt['color'] as Color,
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B73),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Guardar cambio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required String key,
    required String title,
    required String subtitle,
    required Color dotColor,
  }) {
    final isSelected = _selected == key;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF0D3B73) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selected = key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0B2545)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF0D3B73) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D3B73) : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// DETALLE DEL REPORTE (Images 1, 2 & 4)
// -------------------------------------------------------------
class ReportSheet extends StatefulWidget {
  final Report report;
  final AppUser user;
  const ReportSheet({super.key, required this.report, required this.user});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  late final TextEditingController _noteController;
  late Report _currentReport;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
    _noteController = TextEditingController(text: widget.report.staffNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openChangeStatusModal() async {
    final newStatus = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeStatusModal(currentStatus: _currentReport.status),
    );

    if (newStatus != null && newStatus != _currentReport.status) {
      await DataService.updateReportStatus(_currentReport.id, newStatus);
      setState(() {
        _currentReport = Report(
          id: _currentReport.id,
          description: _currentReport.description,
          photoUrl: _currentReport.photoUrl,
          photoBase64: _currentReport.photoBase64,
          status: newStatus,
          staffNote: _currentReport.staffNote,
          reporterId: _currentReport.reporterId,
          reporterName: _currentReport.reporterName,
          lat: _currentReport.lat,
          lng: _currentReport.lng,
          createdAt: _currentReport.createdAt,
          dogId: _currentReport.dogId,
          dogName: _currentReport.dogName,
          dogDeleted: _currentReport.dogDeleted,
          dogStatus: _currentReport.dogStatus,
          incidentType: _currentReport.incidentType,
          photos: _currentReport.photos,
          breedAnalysis: _currentReport.breedAnalysis,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estado actualizado correctamente.')),
        );
      }
    }
  }

  Future<void> _saveNote() async {
    setState(() => _savingNote = true);
    try {
      await DataService.updateReportStaffNote(_currentReport.id, _noteController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Observaciones guardadas.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _deleteReport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar reporte?'),
        content: const Text('Esta acción eliminará el reporte permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataService.deleteReport(_currentReport.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _currentReport;
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
            // Top Bar
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

            // Banner based on status
            if (isResolved)
              _buildBanner(
                title: 'Resuelto',
                subtitle: 'Este reporte ya fue atendido. Aquí ves cómo se resolvió.',
                icon: Icons.check_circle_outline,
                bgColor: const Color(0xFFEAF8F0),
                borderColor: const Color(0xFFB7E4C7),
                iconColor: const Color(0xFF15803D),
              )
            else if (isInReview)
              _buildBanner(
                title: 'En revisión',
                subtitle: 'El personal está revisando tu reporte.',
                icon: Icons.access_time_rounded,
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
                iconColor: const Color(0xFFB45309),
              )
            else
              _buildBanner(
                title: 'Pendiente',
                subtitle: user.isStaff ? 'Reporte pendiente de atención por el personal.' : 'Puedes editar tu reporte hasta que el personal empiece a revisarlo.',
                icon: Icons.warning_amber_rounded,
                bgColor: const Color(0xFFFFF1F2),
                borderColor: const Color(0xFFFECDD3),
                iconColor: const Color(0xFFDC2626),
              ),

            // Staff: Button "Cambiar estado" (Image 4)
            if (user.isStaff) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B73),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _openChangeStatusModal,
                  icon: const Icon(Icons.sync_rounded, size: 20),
                  label: const Text('Cambiar estado', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Student: Si está resuelto, mostrar cómo se resolvió (Image 2)
            if (!user.isStaff && isResolved) ...[
              const Text('Cómo se resolvió', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545))),
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
                    const Text('ACCIONES REALIZADAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(
                      r.staffNote.isNotEmpty ? r.staffNote : 'El personal atendió la incidencia en el campus y el perro se encuentra en buen estado.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Atendido el', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        Text(DateFormat('dd/MM · HH:mm').format(r.createdAt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F2B48))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Detalles Section (Image 4 & 1)
            const Text('Detalles', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545))),
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
                        const Icon(Icons.circle, color: Color(0xFFF59E0B), size: 8),
                        const SizedBox(width: 6),
                        Text(
                          r.dogStatus.isNotEmpty ? r.dogStatus.replaceAll('_', ' ').capitalize() : 'Herido',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0B2545)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _detailRow(
                    'Tipo de incidencia',
                    Text(r.incidentType.isNotEmpty ? r.incidentType.capitalize() : 'Otro', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48))),
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _detailRow(
                    'Fecha',
                    Text(DateFormat('dd/MM · HH:mm').format(r.createdAt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48))),
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _detailRow(
                    'Perro relacionado',
                    Text(r.unidentified ? 'Sin identificar' : (r.dogName ?? 'Sin identificar'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48))),
                  ),
                  if (user.isStaff && r.reporterName.isNotEmpty) ...[
                    const Divider(height: 18, color: Color(0xFFF1F5F9)),
                    _detailRow(
                      'Reportado por',
                      Text(r.reporterName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F2B48))),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Descripción Section (Image 4)
            BreedAnalysisCard(breeds: r.breedAnalysis),
            const Text('Descripción', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545))),
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
                r.description.isNotEmpty ? r.description : 'Perro herido en una pata',
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.35),
              ),
            ),
            const SizedBox(height: 20),

            // Evidencia Section (Image 4)
            const Text('Evidencia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545))),
            const SizedBox(height: 10),
            if (hasPhoto)
              GestureDetector(
                onTap: () => _showPhotoViewer(context, r),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    color: const Color(0xFFF1F5F9),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: reportPhoto(r, fit: BoxFit.contain),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.62),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 17),
                                SizedBox(width: 5),
                                Text('Ampliar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 22),
                    SizedBox(width: 10),
                    Text('Sin fotos adjuntas', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Ubicación Section (Image 4)
            const Text('Ubicación', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545))),
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
                                child: const Icon(Icons.location_on, color: Color(0xFFDC2626), size: 36),
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
                                  'Ubicación del reporte',
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

            // Staff: Observaciones del personal (Image 4)
            if (user.isStaff) ...[
              const SizedBox(height: 20),
              const Text('Observaciones del personal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545))),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Anota las acciones realizadas o lo que observaste',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEBF3FF),
                    foregroundColor: const Color(0xFF1E5BB0),
                  ),
                  onPressed: _savingNote ? null : _saveNote,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Guardar observaciones', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),

              // Button "Eliminar reporte" (Image 4)
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA83232),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: _deleteReport,
                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                  label: const Text('Eliminar reporte', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
              ),
            ],

            // Student: Botón para editar reporte si está pendiente
            if (!user.isStaff && isPending) ...[
              const SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: iconColor.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  void _showPhotoViewer(BuildContext context, Report report) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.88),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(48),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: reportPhoto(report, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper image widgets
Widget _reportImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  if (url.isEmpty) return _missingImage(width: width, height: height);
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => _missingImage(width: width, height: height),
  );
}

Widget reportPhoto(Report report, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  if (report.photoBase64.isNotEmpty) {
    try {
      return Image.memory(
        base64Decode(report.photoBase64),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _missingImage(width: width, height: height),
      );
    } catch (_) {
      return _missingImage(width: width, height: height);
    }
  }
  return _reportImage(report.photoUrl, width: width, height: height, fit: fit);
}

Widget _missingImage({double? width, double? height}) => Container(
      width: width,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
