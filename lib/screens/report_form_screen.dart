import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';

/// Reporte de incidencias con foto, descripción y GPS (RF08-RF11).
class ReportFormScreen extends StatefulWidget {
  final AppUser user;
  const ReportFormScreen({super.key, required this.user});
  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _desc = TextEditingController();
  Uint8List? _photo;
  Dog? _dog; // null = no identificado
  double? _lat, _lng;
  bool _saving = false;
  String? _locError;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final p = await LocationService.current();
      if (!mounted) return;
      setState(() {
        _lat = p.latitude;
        _lng = p.longitude;
        _locError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _locError = e.toString());
    }
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        imageQuality: 55,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (x != null) {
        final bytes = await x.readAsBytes();
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

  Future<void> _send() async {
    if (_photo == null ||
        _desc.text.trim().isEmpty ||
        _lat == null ||
        _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto, descripción y ubicación son obligatorias')));
      return;
    }
    if (_photo!.lengthInBytes > 600 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'La foto es muy pesada. Elige otra imagen (máximo 600 KB).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await DataService.addReport({
        'description': _desc.text.trim(),
        'photoUrl': '',
        'photoBase64': base64Encode(_photo!),
        'lat': _lat,
        'lng': _lng,
        'dogId': _dog?.id,
        'dogName': _dog?.name,
        'reporterId': widget.user.uid,
        'reporterName': widget.user.name,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reporte enviado. ¡Gracias!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar incidencia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Cuéntanos qué ocurrió',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              'Una foto y la ubicación ayudan al personal a responder más rápido.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Center(
                                  child: Icon(Icons.photo_camera_outlined,
                                      size: 48)),
                            )
                          : Image.memory(_photo!,
                              fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Cámara'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
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
          Text('Detalles del reporte',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StreamBuilder<List<Dog>>(
            stream: DataService.dogs(),
            builder: (context, snap) {
              final dogs = snap.data ?? <Dog>[];
              return DropdownButtonFormField<Dog?>(
                initialValue: _dog,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Perro relacionado',
                  prefixIcon: const Icon(Icons.pets_outlined),
                  helperText: snap.hasError
                      ? 'No se pudo cargar el catálogo; puedes enviar el reporte sin identificar.'
                      : dogs.isEmpty
                          ? 'No hay perros registrados. Podrás enviarlo sin identificar.'
                          : 'Elige el perro si lo reconoces.',
                ),
                items: [
                  const DropdownMenuItem<Dog?>(
                      value: null, child: Text('Sin identificar')),
                  for (final d in dogs)
                    DropdownMenuItem<Dog?>(value: d, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _dog = v),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '¿Qué está pasando?',
              hintText:
                  'Describe la situación, el lugar o cualquier detalle útil.',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 66),
                  child: Icon(Icons.notes_outlined)),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                  _lat != null ? Icons.location_on : Icons.location_searching,
                  color: _lat != null
                      ? const Color(0xFF2A5FC4)
                      : Theme.of(context).colorScheme.primary),
              title: Text(
                  _lat != null ? 'Ubicación adjunta' : 'Obteniendo ubicación'),
              subtitle: Text(_lat != null
                  ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                  : (_locError ??
                      'Comprueba el permiso de ubicación del navegador o teléfono.')),
              trailing: IconButton(
                  tooltip: 'Actualizar ubicación',
                  icon: const Icon(Icons.refresh),
                  onPressed: _locate),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _saving ? null : _send,
              child: Text(_saving ? 'Enviando...' : 'Enviar reporte')),
        ],
      ),
    );
  }
}
