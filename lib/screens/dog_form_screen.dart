import 'dart:typed_data';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'medical_entry_screen.dart';
import 'vaccine_form_screen.dart';

/// Registro de perros (RF04) - solo personal.
class DogFormScreen extends StatefulWidget {
  final Dog? dog;
  const DogFormScreen({super.key, this.dog});
  @override
  State<DogFormScreen> createState() => _DogFormScreenState();
}

class _DogFormScreenState extends State<DogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _color = TextEditingController();
  final _desc = TextEditingController();
  final _age = TextEditingController(text: '3');
  final _allergies = TextEditingController(text: 'Ninguna conocida');
  final _medicalTitle = TextEditingController(text: 'Registro inicial');
  final _medicalDescription = TextEditingController();
  final _medicalVet = TextEditingController();
  final _medicalDiagnosis = TextEditingController();
  final _medicalTreatment = TextEditingController();
  final _vaccineNotes = TextEditingController();
  static const _vaccineTypes = [
    'Rabia',
    'Parvovirus',
    'Desparasitación',
    'Moquillo',
    'Polivalente (Séxtuple)',
    'Otro tratamiento',
  ];
  String? _vaccineName;
  DateTime _medicalDate = DateTime.now();
  DateTime? _medicalNextVisit;
  DateTime _vaccineDate = DateTime.now();
  DateTime? _vaccineNextDate;
  String _sex = 'Macho';
  bool _collar = false, _sterilized = false, _saving = false;
  double _uploadProgress = 0;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    final dog = widget.dog;
    if (dog != null) {
      _name.text = dog.name;
      _color.text = dog.color;
      _desc.text = dog.description;
      _age.text = dog.age;
      _allergies.text = dog.allergies;
      _sex = dog.sex;
      _collar = dog.hasRedCollar;
      _sterilized = dog.isSterilized;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _desc.dispose();
    _age.dispose();
    _allergies.dispose();
    _medicalTitle.dispose();
    _medicalDescription.dispose();
    _medicalVet.dispose();
    _medicalDiagnosis.dispose();
    _medicalTreatment.dispose();
    _vaccineNotes.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length >= 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'La imagen debe pesar menos de 5 MB. Elige otra foto.'),
              ),
            );
          }
          return;
        }
        if (mounted) setState(() => _photo = bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo abrir la cámara o la galería.')),
        );
      }
    }
  }

  Future<void> _pickDate(
      {required bool forVaccine, bool nextVisit = false}) async {
    final current = forVaccine
        ? (nextVisit ? _vaccineNextDate ?? _vaccineDate : _vaccineDate)
        : (nextVisit ? _medicalNextVisit ?? _medicalDate : _medicalDate);
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: nextVisit
          ? DateTime.now().add(const Duration(days: 365 * 3))
          : DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (forVaccine) {
        if (nextVisit) {
          _vaccineNextDate = selected;
        } else {
          _vaccineDate = selected;
        }
      } else if (nextVisit) {
        _medicalNextVisit = selected;
      } else {
        _medicalDate = selected;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final photoUrl = _photo == null
          ? (widget.dog?.photoUrl ?? '')
          : await DataService.uploadPhoto(
              _photo!,
              'canes',
              onProgress: (progress) {
                if (mounted) setState(() => _uploadProgress = progress);
              },
            );
      final data = {
        'name': _name.text.trim(),
        'sex': _sex,
        'color': _color.text.trim(),
        'description': _desc.text.trim(),
        'hasRedCollar': _collar,
        'photoUrl': photoUrl,
        'age': _age.text.trim(),
        'allergies': _allergies.text.trim(),
        'isSterilized': _sterilized,
      };
      if (widget.dog == null) {
        await DataService.addDog(
          data,
          initialMedicalEntry: _medicalDescription.text.trim().isEmpty
              ? null
              : {
                  'title': _medicalTitle.text.trim().isEmpty
                      ? 'Registro inicial'
                      : _medicalTitle.text.trim(),
                  'description': _medicalDescription.text.trim(),
                  'date': Timestamp.fromDate(_medicalDate),
                  'vetOrClinic': _medicalVet.text.trim(),
                  'diagnosis': _medicalDiagnosis.text.trim(),
                  'treatment': _medicalTreatment.text.trim(),
                  'nextVisit': _medicalNextVisit == null
                      ? null
                      : Timestamp.fromDate(_medicalNextVisit!),
                  'createdAt': FieldValue.serverTimestamp(),
                },
          initialVaccine: _vaccineName == null
              ? null
              : {
                  'name': _vaccineName!,
                  'appliedAt': Timestamp.fromDate(_vaccineDate),
                  'nextDate': _vaccineNextDate == null
                      ? null
                      : Timestamp.fromDate(_vaccineNextDate!),
                  'notes': _vaccineNotes.text.trim(),
                },
        );
      } else {
        await DataService.updateDog(widget.dog!.id, data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.dog == null
                ? 'Perro añadido al catálogo.'
                : 'Cambios guardados.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        final message = switch (error) {
          FirebaseException(code: 'bucket-not-found') =>
            'Firebase Storage no está inicializado. Créalo en la consola del proyecto y vuelve a intentarlo.',
          FirebaseException(code: 'unauthorized' || 'unauthenticated') =>
            'Firebase Storage rechazó el acceso. Revisa que la sesión esté activa y publica sus reglas.',
          FirebaseException(code: 'retry-limit-exceeded') =>
            'Se agotó el tiempo de carga. Revisa tu conexión e inténtalo de nuevo.',
          TimeoutException() =>
            'La carga de la foto excedió 90 segundos. Revisa Firebase Storage y la conexión.',
          ArgumentError() =>
            error.toString().replaceFirst('Invalid argument(s): ', ''),
          _ =>
            'No se pudo guardar el perro. ${error is FirebaseException ? 'Firebase (${error.code}): ${error.message ?? ''}' : error}',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(message), duration: const Duration(seconds: 7)),
        );
        setState(() => _saving = false);
      }
    }
  }

  Widget _healthModules(BuildContext context, ColorScheme colors) {
    final existingDog = widget.dog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleCard(
          colors: colors,
          icon: Icons.medical_services_outlined,
          title: 'Historial médico',
          subtitle: existingDog == null
              ? 'Registra una consulta inicial (opcional).'
              : 'Consultas, diagnósticos y tratamientos.',
          children: existingDog == null
              ? [
                  TextFormField(
                    controller: _medicalTitle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Título de la consulta',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dateSelector(
                    context,
                    label: 'Fecha de consulta',
                    date: _medicalDate,
                    onTap: () => _pickDate(forVaccine: false),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _medicalVet,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Veterinario o clínica',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _medicalDescription,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Síntomas, consulta u observaciones',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _medicalDiagnosis,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Diagnóstico'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _medicalTreatment,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Tratamiento',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dateSelector(
                    context,
                    label: 'Próxima visita (opcional)',
                    date: _medicalNextVisit,
                    emptyLabel: 'Sin fecha programada',
                    onTap: () => _pickDate(
                      forVaccine: false,
                      nextVisit: true,
                    ),
                  ),
                ]
              : [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicalEntryScreen(dog: existingDog),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir al historial médico'),
                    ),
                  ),
                ],
        ),
        const SizedBox(height: 14),
        _moduleCard(
          colors: colors,
          icon: Icons.vaccines_outlined,
          title: 'Vacunas aplicadas',
          subtitle: existingDog == null
              ? 'Registra una vacuna aplicada (opcional).'
              : 'Dosis aplicadas y próximas fechas.',
          children: existingDog == null
              ? [
                  DropdownButtonFormField<String>(
                    initialValue: _vaccineName,
                    decoration: const InputDecoration(
                      labelText: 'Vacuna aplicada (opcional)',
                      prefixIcon: Icon(Icons.vaccines_outlined),
                    ),
                    hint: const Text('Selecciona una vacuna'),
                    items: _vaccineTypes
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _vaccineName = value),
                  ),
                  const SizedBox(height: 10),
                  _dateSelector(
                    context,
                    label: 'Fecha de aplicación',
                    date: _vaccineDate,
                    onTap: () => _pickDate(forVaccine: true),
                  ),
                  const SizedBox(height: 10),
                  _dateSelector(
                    context,
                    label: 'Próxima dosis (opcional)',
                    date: _vaccineNextDate,
                    emptyLabel: 'Sin fecha programada',
                    onTap: () => _pickDate(
                      forVaccine: true,
                      nextVisit: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _vaccineNotes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      hintText: 'Lote, veterinario o reacciones',
                      alignLabelWithHint: true,
                    ),
                  ),
                ]
              : [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VaccineFormScreen(dog: existingDog),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir vacuna'),
                    ),
                  ),
                ],
        ),
      ],
    );
  }

  Widget _moduleCard({
    required ColorScheme colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _dateSelector(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    String emptyLabel = 'Selecciona una fecha',
  }) {
    final formatted = date == null
        ? emptyLabel
        : MaterialLocalizations.of(context).formatMediumDate(date);
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(formatted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.dog == null ? 'Registrar perro' : 'Editar perro')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Text(widget.dog == null ? 'Nuevo integrante' : 'Editar ficha',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                'Completa la información para agregarlo al catálogo del campus.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 190,
                        child: _photo == null
                            ? ColoredBox(
                                color: colors.surfaceContainerHighest,
                                child: Icon(Icons.add_a_photo_outlined,
                                    size: 44, color: colors.primary),
                              )
                            : Image.memory(_photo!, fit: BoxFit.cover),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Cámara'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _pick(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galería'),
                          ),
                        ),
                      ],
                    ),
                    Text(
                        'La foto es opcional. Para guardarla, Firebase Storage debe estar habilitado.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Datos del perro',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nombre', prefixIcon: Icon(Icons.pets_outlined)),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'El nombre es obligatorio.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(
                  labelText: 'Sexo', prefixIcon: Icon(Icons.wc_outlined)),
              items: const [
                DropdownMenuItem(value: 'Macho', child: Text('Macho')),
                DropdownMenuItem(value: 'Hembra', child: Text('Hembra')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _sex = value ?? _sex),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _color,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Color y rasgos',
                  prefixIcon: Icon(Icons.palette_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Edad aproximada (años)',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              validator: (value) {
                final age = int.tryParse(value?.trim() ?? '');
                return age == null || age < 0 || age > 40
                    ? 'Ingresa una edad entre 0 y 40 años.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _allergies,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alergias o condiciones',
                prefixIcon: Icon(Icons.health_and_safety_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Descripción o zona habitual',
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile.adaptive(
                title: const Text('Tiene collar rojo'),
                subtitle: const Text('Ayuda a identificarlo en el campus.'),
                secondary: Icon(Icons.circle,
                    size: 17, color: _collar ? Colors.red : colors.outline),
                value: _collar,
                onChanged:
                    _saving ? null : (value) => setState(() => _collar = value),
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: SwitchListTile.adaptive(
                title: const Text('Esterilizado'),
                value: _sterilized,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _sterilized = value),
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            _healthModules(context, colors),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving
                  ? _photo != null
                      ? 'Subiendo foto ${(100 * _uploadProgress).round()}%…'
                      : 'Guardando…'
                  : widget.dog == null
                      ? 'Guardar perro'
                      : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
