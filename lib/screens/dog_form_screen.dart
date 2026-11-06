import 'dart:typed_data';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'dog_detail_screen.dart';

/// Registro de perros (RF04) - solo personal.
class DogFormScreen extends StatefulWidget {
  final AppUser user;
  final Dog? dog;
  const DogFormScreen({super.key, required this.user, this.dog});
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
  final _initialMedical = TextEditingController();
  final _initialVaccineNotes = TextEditingController();
  static const _vaccineTypes = [
    'Rabia',
    'Parvovirus',
    'Desparasitación',
    'Moquillo',
    'Polivalente (Séxtuple)',
    'Otro tratamiento',
  ];
  String? _initialVaccine;
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
    _initialMedical.dispose();
    _initialVaccineNotes.dispose();
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
      String dogId;
      if (widget.dog == null) {
        final medicalText = _initialMedical.text.trim();
        dogId = await DataService.addDog(
          data,
          initialMedicalEntry: medicalText.isEmpty
              ? null
              : {
                  'title': 'Historial médico inicial',
                  'description': medicalText,
                  'date': Timestamp.fromDate(DateTime.now()),
                  'createdAt': FieldValue.serverTimestamp(),
                },
          initialVaccine: _initialVaccine == null
              ? null
              : {
                  'name': _initialVaccine,
                  'appliedAt': Timestamp.fromDate(DateTime.now()),
                  'nextDate': null,
                  'notes': _initialVaccineNotes.text.trim(),
                },
        );
      } else {
        await DataService.updateDog(widget.dog!.id, data);
        dogId = widget.dog!.id;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.dog == null
                ? 'Perro añadido al catálogo.'
                : 'Cambios guardados.'),
          ),
        );
        if (widget.dog == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DogDetailScreen(dogId: dogId, user: widget.user),
            ),
          );
        } else {
          Navigator.pop(context);
        }
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
            if (widget.dog == null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Historial médico y vacunas (opcional)'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextFormField(
                    controller: _initialMedical,
                    enabled: !_saving,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Historial médico inicial',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _initialVaccine,
                    decoration: const InputDecoration(
                      labelText: 'Vacuna aplicada',
                      prefixIcon: Icon(Icons.vaccines_outlined),
                    ),
                    hint: const Text('Selecciona una vacuna (opcional)'),
                    items: _vaccineTypes
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _initialVaccine = value),
                  ),
                  if (_initialVaccine != null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _initialVaccineNotes,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notas de la vacuna',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
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
