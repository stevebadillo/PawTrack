import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class MedicalEntryScreen extends StatefulWidget {
  final Dog? dog;
  final String? dogName;
  const MedicalEntryScreen({super.key, this.dog, this.dogName});

  @override
  State<MedicalEntryScreen> createState() => _MedicalEntryScreenState();
}

class _MedicalEntryScreenState extends State<MedicalEntryScreen> {
  DateTime _date = DateTime.now();
  final _title = TextEditingController();
  final _vet = TextEditingController();
  final _desc = TextEditingController();
  final _diagnosis = TextEditingController();
  final _treatment = TextEditingController();
  DateTime? _nextVisit;
  bool _saving = false;
  final List<_MedicalAttachment> _attachments = [];

  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() {
    _title.dispose();
    _vet.dispose();
    _desc.dispose();
    _diagnosis.dispose();
    _treatment.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickNextVisit() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date.add(const Duration(days: 14)),
      firstDate: _date,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;

    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (t == null) return;

    setState(() {
      _nextVisit = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _addAttachment() async {
    final choice = await showModalBottomSheet<_AttachmentType>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Añadir fotografía'),
              onTap: () => Navigator.pop(context, _AttachmentType.photo),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Añadir PDF'),
              onTap: () => Navigator.pop(context, _AttachmentType.pdf),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      if (choice == _AttachmentType.photo) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        if (image == null) return;
        final bytes = await image.readAsBytes();
        _validateAttachmentSize(bytes);
        if (mounted) {
          setState(() => _attachments.add(
                _MedicalAttachment(
                    name: image.name, bytes: bytes, isPdf: false),
              ));
        }
        return;
      }

      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      _validateAttachmentSize(bytes);
      if (String.fromCharCodes(bytes.take(5)) != '%PDF-') {
        throw FormatException('${file.name} no es un PDF válido.');
      }
      if (mounted) {
        setState(() => _attachments.add(
              _MedicalAttachment(name: file.name, bytes: bytes, isPdf: true),
            ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo adjuntar el archivo: $error')),
        );
      }
    }
  }

  void _validateAttachmentSize(Uint8List bytes) {
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Cada archivo debe pesar como máximo 10 MB.');
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El título y la descripción son obligatorios.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final entryData = {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'date': _date,
        'vetOrClinic': _vet.text.trim(),
        'diagnosis': _diagnosis.text.trim(),
        'treatment': _treatment.text.trim(),
        'nextVisit': _nextVisit,
      };
      final documents = <String>[];
      for (final attachment in _attachments) {
        final url = attachment.isPdf
            ? await DataService.uploadPdf(attachment.bytes, attachment.name)
            : await DataService.uploadPhoto(
                attachment.bytes,
                'registros_medicos',
              );
        documents.add(url);
      }
      entryData['documents'] = documents;

      if (widget.dog != null) {
        await DataService.addMedicalEntry(widget.dog!.id, entryData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrada médica guardada con éxito.')),
          );
          Navigator.pop(context);
        }
      } else {
        // Modo retorno de datos para creación de perro
        if (mounted) {
          Navigator.pop(context, entryData);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  'Nueva entrada médica',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2B48),
                  ),
                ),
                const SizedBox(width: 42),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
        children: [
          // 1. Fecha *
          _label('Fecha', isRequired: true),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Text(_fmt.format(_date),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0B2545))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Título *
          _label('Título', isRequired: true),
          _inputField(_title, 'Ej. Revisión por vómitos',
              icon: Icons.edit_outlined),
          const SizedBox(height: 18),

          // 3. Veterinario o clínica
          _label('Veterinario o clínica'),
          _inputField(_vet, 'Nombre del veterinario o clínica',
              icon: Icons.person_outline),
          const SizedBox(height: 18),

          // 4. Descripción *
          _label('Descripción', isRequired: true),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe la consulta, síntomas u observaciones...',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 50),
                child: Icon(Icons.description_outlined,
                    size: 20, color: Color(0xFF64748B)),
              ),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 18),

          // 5. Diagnóstico
          _label('Diagnóstico'),
          _inputField(_diagnosis, 'Ej. Gastroenteritis',
              icon: Icons.medical_services_outlined),
          const SizedBox(height: 18),

          // 6. Tratamiento
          _label('Tratamiento'),
          _inputField(_treatment, 'Medicamentos, dosis e indicaciones...',
              icon: Icons.medication_outlined),
          const SizedBox(height: 18),

          // 7. Próxima visita (opcional)
          _label('Próxima visita (opcional)'),
          InkWell(
            onTap: _pickNextVisit,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Text(
                    _nextVisit != null
                        ? _fmt.format(_nextVisit!)
                        : 'Selecciona una fecha',
                    style: TextStyle(
                      fontWeight: _nextVisit != null
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _nextVisit != null
                          ? const Color(0xFF0B2545)
                          : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 8. Adjuntar documentos (opcional)
          const Row(
            children: [
              Icon(Icons.attach_file_rounded,
                  size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text('Adjuntar documentos ',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Color(0xFF0B2545))),
              Text('(opcional)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Añade fotografías o PDFs (máximo 10 MB por archivo).',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _saving ? null : _addAttachment,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Añadir fotografía o PDF',
                    style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          for (var index = 0; index < _attachments.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _attachments[index].isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: const Color(0xFF2563EB),
              ),
              title: Text(
                _attachments[index].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Quitar archivo',
                onPressed: _saving
                    ? null
                    : () => setState(() => _attachments.removeAt(index)),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D3B73),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B73),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: Color(0xFF0B2545))),
          if (isRequired)
            const Text(' *',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint,
      {IconData? icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: const Color(0xFF64748B))
            : null,
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
    );
  }
}

enum _AttachmentType { photo, pdf }

class _MedicalAttachment {
  final String name;
  final Uint8List bytes;
  final bool isPdf;

  const _MedicalAttachment({
    required this.name,
    required this.bytes,
    required this.isPdf,
  });
}
