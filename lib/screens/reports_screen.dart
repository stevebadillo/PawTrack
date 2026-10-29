import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

const statusLabels = {
  'pendiente': 'Pendiente',
  'en_atencion': 'En atención',
  'resuelto': 'Resuelto'
};

Color statusColor(String s) => s == 'resuelto'
    ? const Color(0xFF2A5FC4)
    : (s == 'en_atencion' ? const Color(0xFFE8521A) : Colors.red);

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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Volver',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Text('Detalle del reporte',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
              ],
            ),
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: reportPhoto(r, height: 220)),
            const SizedBox(height: 12),
            Text(
                r.unidentified
                    ? 'Perro sin identificar'
                    : (r.dogName ?? 'Perro'),
                style: Theme.of(context).textTheme.titleLarge),
            Text('Reportado por ${r.reporterName}'),
            const SizedBox(height: 8),
            Text(r.description),
            if (r.staffNote.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nota del personal',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(r.staffNote),
                    ],
                  ),
                ),
              ),
            ],
            Text(
                'Ubicación: ${r.lat.toStringAsFixed(5)}, ${r.lng.toStringAsFixed(5)}'),
            if (!user.isStaff &&
                user.uid == r.reporterId &&
                r.status == 'pendiente') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _editDescription(r),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar descripción'),
              ),
            ],
            if (user.isStaff) ...[
              const Divider(height: 32),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Nota para el estudiante (opcional)',
                  hintText: 'Comparte una actualización o información útil.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _savingNote ? null : () => _saveNote(r),
                  icon: _savingNote
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar nota'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Cambiar estado'),
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
              if (r.unidentified) ...[
                const SizedBox(height: 12),
                const Text('Identificar perro'),
                StreamBuilder<List<Dog>>(
                  stream: DataService.dogs(),
                  builder: (context, snap) => DropdownButton<Dog>(
                    isExpanded: true,
                    hint: const Text('Seleccionar perro registrado'),
                    items: [
                      for (final d in snap.data ?? <Dog>[])
                        DropdownMenuItem(value: d, child: Text(d.name))
                    ],
                    onChanged: (d) async {
                      if (d == null) return;
                      await DataService.linkReportToDog(r.id, d);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _deleteReport(r),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar reporte'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
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
