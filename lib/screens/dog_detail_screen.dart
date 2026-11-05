import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'dog_form_screen.dart';
import 'medical_entry_screen.dart';
import 'report_form_screen.dart';
import 'vaccine_form_screen.dart';

final _fmt = DateFormat('dd/MM/yyyy');

class DogDetailScreen extends StatelessWidget {
  final String dogId;
  final AppUser user;
  const DogDetailScreen({super.key, required this.dogId, required this.user});

  Future<void> _confirmDogDeletion(BuildContext context, Dog dog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar a ${dog.name}?'),
        content: const Text(
          'Se eliminarán su ficha y sus historiales médicos. Los reportes anteriores se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataService.deleteDog(dog);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el perro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Dog>(
      stream: DataService.dog(dogId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
                child: Text('No se pudo cargar la ficha del perro.')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final d = snap.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(66),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Icon(Icons.chevron_left_rounded,
                              color: Color(0xFF0F2B48), size: 26),
                        ),
                      ),
                    ),
                    const Text(
                      'Ficha del perro',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2B48),
                      ),
                    ),
                    if (user.isStaff)
                      IconButton(
                        tooltip: 'Eliminar perro',
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFDC2626)),
                        onPressed: () => _confirmDogDeletion(context, d),
                      )
                    else
                      const SizedBox(width: 42),
                  ],
                ),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            children: [
              // Top Warm Card (Beige pastel with watermark)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EE),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFDE7C7)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Watermark paws
                      Positioned(
                        top: -10,
                        left: -10,
                        child: Icon(Icons.pets,
                            size: 70,
                            color: const Color(0xFFF9E4C5).withOpacity(0.5)),
                      ),
                      Positioned(
                        bottom: -15,
                        right: -10,
                        child: Icon(Icons.pets,
                            size: 85,
                            color: const Color(0xFFF9E4C5).withOpacity(0.5)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            // Dog Photo Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: 105,
                                height: 115,
                                child: d.photoUrl.isNotEmpty
                                    ? Image.network(
                                        d.photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _photoPlaceholder(),
                                      )
                                    : _photoPlaceholder(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Dog Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0B2545),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${d.sex} · ${d.color}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (d.hasRedCollar)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xFFFDE7C7)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.circle,
                                              color: Color(0xFFDC2626),
                                              size: 8),
                                          SizedBox(width: 6),
                                          Text(
                                            'Collar rojo',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0B2545),
                                            ),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (user.isStaff) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  DogFormScreen(dog: d, user: user)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                        onPressed: () => _confirmDogDeletion(context, d),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              _medicalFacts(d),
              const SizedBox(height: 20),

              // Los reportes los registra el estudiantado.
              if (!user.isStaff)
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D3B73),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReportFormScreen(user: user)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text(
                      'Reportar incidencia',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Vacunas Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vacunas',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2545)),
                  ),
                  if (user.isStaff)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1E5BB0)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VaccineFormScreen(dog: d),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Añadir vacuna',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              StreamBuilder<List<Vaccine>>(
                stream: DataService.vaccines(dogId),
                builder: (context, vs) {
                  final list = vs.data ?? [];
                  if (vs.connectionState == ConnectionState.waiting &&
                      !vs.hasData) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator()));
                  }

                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          'No hay vacunas registradas aún.',
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) {
                        final v = list[i];
                        final isUpcoming = v.nextDate != null;

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isUpcoming
                                      ? const Color(0xFFFEF3E2)
                                      : const Color(0xFFEAF8F0),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isUpcoming
                                      ? Icons.access_time_rounded
                                      : Icons.shield_outlined,
                                  color: isUpcoming
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF15803D),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: Color(0xFF0B2545),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Aplicada: ${_fmt.format(v.appliedAt)}',
                                      style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12),
                                    ),
                                    if (v.nextDate != null)
                                      Text(
                                        'Próxima dosis: ${_fmt.format(v.nextDate!)}',
                                        style: const TextStyle(
                                          color: Color(0xFFB45309),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Historial médico',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2545)),
                  ),
                  if (user.isStaff)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicalEntryScreen(dog: d),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Registrar'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<MedicalEntry>>(
                stream: DataService.medicalEntries(dogId),
                builder: (context, entriesSnapshot) {
                  final entries =
                      entriesSnapshot.data ?? const <MedicalEntry>[];
                  if (entriesSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !entriesSnapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (entries.isEmpty) {
                    return _historyCard(
                      date: d.createdAt,
                      title: 'Registro en PawTrack',
                      description: d.description.isNotEmpty
                          ? d.description
                          : 'Perro ingresado al catálogo de seguimiento sanitario.',
                    );
                  }
                  return Column(
                    children: [
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _historyCard(
                            date: entry.date,
                            title: entry.title,
                            description: entry.description,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _medicalFacts(Dog dog) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12.5)),
              ),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Color(0xFF0B2545),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5)),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Datos médicos',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B2545))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              row('Esterilizado', dog.isSterilized ? 'Sí' : 'No'),
              const Divider(height: 1),
              row('Edad aproximada', '${dog.age} años'),
              const Divider(height: 1),
              row('Alergias o condiciones', dog.allergies),
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyCard({
    required DateTime date,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmt.format(date),
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 11)),
                const SizedBox(height: 5),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0B2545))),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5FB),
      child: const Center(
        child: Icon(Icons.pets, size: 40, color: Color(0xFF93C5FD)),
      ),
    );
  }
}

class _VaccineDialog extends StatefulWidget {
  final String dogId;
  const _VaccineDialog({required this.dogId});
  @override
  State<_VaccineDialog> createState() => _VaccineDialogState();
}

class _VaccineDialogState extends State<_VaccineDialog> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  DateTime _applied = DateTime.now();
  DateTime? _next;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickApplied() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _applied,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _applied = d);
  }

  Future<void> _pickNext() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _applied.add(const Duration(days: 365)),
      firstDate: _applied,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d != null) setState(() => _next = d);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await DataService.addVaccine(
        widget.dogId,
        _name.text.trim(),
        _applied,
        _next,
        _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva vacuna o tratamiento',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Nombre (ej: Antirrábica, Parvovirus)'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de aplicación'),
              subtitle: Text(_fmt.format(_applied)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickApplied,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Próxima dosis (opcional)'),
              subtitle:
                  Text(_next == null ? 'No programada' : _fmt.format(_next!)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickNext,
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notas adicionales'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFF0D3B73)),
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
