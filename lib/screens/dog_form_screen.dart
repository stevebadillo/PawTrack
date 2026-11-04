import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/data_service.dart';

/// Registro de perros (RF04) - solo personal.
class DogFormScreen extends StatefulWidget {
  const DogFormScreen({super.key});
  @override
  State<DogFormScreen> createState() => _DogFormScreenState();
}

class _DogFormScreenState extends State<DogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _color = TextEditingController();
  final _desc = TextEditingController();
  String _sex = 'Macho';
  bool _collar = false, _saving = false;
  Uint8List? _photo;

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _desc.dispose();
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
      final photoUrl =
          _photo == null ? '' : await DataService.uploadPhoto(_photo!, 'dogs');
      await DataService.addDog({
        'name': _name.text.trim(),
        'sex': _sex,
        'color': _color.text.trim(),
        'description': _desc.text.trim(),
        'hasRedCollar': _collar,
        'photoUrl': photoUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perro añadido al catálogo.')));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_photo == null
                ? 'No se pudo guardar. Comprueba tu conexión.'
                : 'No se pudo subir la foto. Firebase Storage requiere estar habilitado.'),
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar perro')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Text('Nuevo integrante',
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Guardando…' : 'Guardar perro'),
            ),
          ],
        ),
      ),
    );
  }
}
