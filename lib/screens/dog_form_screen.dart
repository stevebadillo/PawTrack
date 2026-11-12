import 'dart:typed_data';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'dog_detail_screen.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

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
  String _sex = 'Macho';
  bool _collar = false, _sterilized = false, _saving = false;
  double _uploadProgress = 0;
  Uint8List? _photo;

  // Inline medical entries and vaccines collected before saving the dog
  final List<Map<String, dynamic>> _medicalEntries = [];
  final List<Map<String, dynamic>> _vaccineEntries = [];

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

  // ── Medical entry inline dialog ──
  Future<void> _addMedicalEntry() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InlineMedicalEntrySheet(),
    );
    if (result != null && mounted) {
      setState(() => _medicalEntries.add(result));
    }
  }

  // ── Vaccine inline dialog ──
  Future<void> _addVaccineEntry() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InlineVaccineSheet(),
    );
    if (result != null && mounted) {
      setState(() => _vaccineEntries.add(result));
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
        // Pass the first medical entry and first vaccine via addDog batch.
        // Additional entries are saved after creation.
        final firstMedical = _medicalEntries.isNotEmpty
            ? {
                'title': _medicalEntries.first['title'] as String,
                'description': _medicalEntries.first['description'] as String,
                'date': Timestamp.fromDate(
                    _medicalEntries.first['date'] as DateTime),
                'vetOrClinic':
                    _medicalEntries.first['vetOrClinic'] as String? ?? '',
                'diagnosis':
                    _medicalEntries.first['diagnosis'] as String? ?? '',
                'treatment':
                    _medicalEntries.first['treatment'] as String? ?? '',
                'createdAt': FieldValue.serverTimestamp(),
              }
            : null;
        final firstVaccine = _vaccineEntries.isNotEmpty
            ? {
                'name': _vaccineEntries.first['name'] as String,
                'appliedAt': Timestamp.fromDate(
                    _vaccineEntries.first['appliedAt'] as DateTime),
                'nextDate': _vaccineEntries.first['nextDate'] != null
                    ? Timestamp.fromDate(
                        _vaccineEntries.first['nextDate'] as DateTime)
                    : null,
                'notes': _vaccineEntries.first['notes'] as String? ?? '',
              }
            : null;

        dogId = await DataService.addDog(
          data,
          initialMedicalEntry: firstMedical,
          initialVaccine: firstVaccine,
        );

        // Save remaining entries (index 1+)
        for (var i = 1; i < _medicalEntries.length; i++) {
          final e = _medicalEntries[i];
          await DataService.addMedicalEntry(dogId, {
            'title': e['title'],
            'description': e['description'],
            'date': e['date'],
            'vetOrClinic': e['vetOrClinic'] ?? '',
            'diagnosis': e['diagnosis'] ?? '',
            'treatment': e['treatment'] ?? '',
          });
        }
        for (var i = 1; i < _vaccineEntries.length; i++) {
          final v = _vaccineEntries[i];
          await DataService.addVaccine(
            dogId,
            v['name'] as String,
            v['appliedAt'] as DateTime,
            v['nextDate'] as DateTime?,
            v['notes'] as String? ?? '',
          );
        }
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
    final isNew = widget.dog == null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
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
                const SizedBox(width: 14),
                Text(
                  isNew ? 'Añadir perro' : 'Editar perro',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2B48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
          children: [
            // ── FOTO ──
            _sectionLabel('Foto'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: _photo != null
                          ? Image.memory(_photo!, fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFFF1F5FB),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.pets,
                                      size: 40, color: Color(0xFF93C5FD)),
                                  SizedBox(height: 6),
                                  Text('Añade una foto del perro',
                                      style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _actionChip(
                            icon: Icons.camera_alt_outlined,
                            label: 'Cámara',
                            onTap: _saving
                                ? null
                                : () => _pick(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionChip(
                            icon: Icons.photo_library_outlined,
                            label: 'Galería',
                            onTap: _saving
                                ? null
                                : () => _pick(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── IDENTIFICACIÓN ──
            _sectionLabel('Identificación'),
            _inputField(
              controller: _name,
              hint: 'Nombre del perro',
              icon: Icons.pets_outlined,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'El nombre es obligatorio.'
                  : null,
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _age,
              hint: '3',
              icon: Icons.cake_outlined,
              label: 'Edad aproximada',
              keyboardType: TextInputType.number,
              validator: (v) {
                final age = int.tryParse(v?.trim() ?? '');
                return age == null || age < 0 || age > 40
                    ? 'Ingresa una edad entre 0 y 40 años.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _allergies,
              hint: 'Ninguna conocida',
              icon: Icons.health_and_safety_outlined,
              label: 'Alergias o condiciones',
            ),
            const SizedBox(height: 22),

            // ── SEXO ──
            _sectionLabel('Sexo'),
            _toggleRow(
              options: const ['Macho', 'Hembra'],
              selected: _sex,
              onChanged: (v) => setState(() => _sex = v),
            ),
            const SizedBox(height: 22),

            // ── COLLAR ──
            _sectionLabel('Collar'),
            _toggleRow(
              options: const ['Rojo', 'Sin collar'],
              selected: _collar ? 'Rojo' : 'Sin collar',
              onChanged: (v) => setState(() => _collar = v == 'Rojo'),
            ),
            const SizedBox(height: 22),

            // ── DESCRIPCIÓN ──
            _sectionLabel('Descripción'),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Rasgos, carácter, dónde suele estar',
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
            const SizedBox(height: 22),

            // ── DATOS MÉDICOS ──
            _sectionLabel('Datos médicos'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile.adaptive(
                title: const Text('Esterilizado',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF0B2545))),
                value: _sterilized,
                activeColor: const Color(0xFF0D3B73),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _sterilized = value),
              ),
            ),
            const SizedBox(height: 12),

            // ── "+ Añadir a historial médico" button ──
            _addEntryButton(
              icon: Icons.add,
              label: 'Añadir a historial médico',
              onTap: _saving ? null : _addMedicalEntry,
            ),

            // Show added medical entries
            if (_medicalEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < _medicalEntries.length; i++)
                _entryChip(
                  icon: Icons.medical_services_outlined,
                  title: _medicalEntries[i]['title'] as String,
                  subtitle:
                      _dateFmt.format(_medicalEntries[i]['date'] as DateTime),
                  onRemove: () =>
                      setState(() => _medicalEntries.removeAt(i)),
                ),
            ],
            const SizedBox(height: 22),

            // ── VACUNAS APLICADAS ──
            _sectionLabel('Vacunas aplicadas'),
            _addEntryButton(
              icon: Icons.add,
              label: 'Añadir vacuna',
              onTap: _saving ? null : _addVaccineEntry,
            ),

            // Show added vaccines
            if (_vaccineEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var i = 0; i < _vaccineEntries.length; i++)
                _entryChip(
                  icon: Icons.vaccines_outlined,
                  title: _vaccineEntries[i]['name'] as String,
                  subtitle: _dateFmt
                      .format(_vaccineEntries[i]['appliedAt'] as DateTime),
                  onRemove: () =>
                      setState(() => _vaccineEntries.removeAt(i)),
                ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
      // ── BOTTOM BAR: Guardar perro ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B73),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _saving
                    ? _photo != null
                        ? 'Subiendo foto ${(100 * _uploadProgress).round()}%…'
                        : 'Guardando…'
                    : isNew
                        ? 'Guardar perro'
                        : 'Guardar cambios',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ──

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0B2545),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
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

  Widget _toggleRow({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _saving ? null : () => onChanged(options[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected == options[i]
                      ? const Color(0xFF0D3B73)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: selected == options[i]
                        ? const Color(0xFF0D3B73)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected == options[i])
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child:
                            Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                    Text(
                      options[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: selected == options[i]
                            ? Colors.white
                            : const Color(0xFF0B2545),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D3B73),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _addEntryButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF2563EB), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryChip({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D3B73)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0B2545))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE BOTTOM SHEET — Nueva entrada médica
// ─────────────────────────────────────────────────────────────────────────────
class _InlineMedicalEntrySheet extends StatefulWidget {
  const _InlineMedicalEntrySheet();
  @override
  State<_InlineMedicalEntrySheet> createState() =>
      _InlineMedicalEntrySheetState();
}

class _InlineMedicalEntrySheetState extends State<_InlineMedicalEntrySheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _vet = TextEditingController();
  final _diagnosis = TextEditingController();
  final _treatment = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _vet.dispose();
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

  void _save() {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El título y la descripción son obligatorios.')),
      );
      return;
    }
    Navigator.pop(context, {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'date': _date,
      'vetOrClinic': _vet.text.trim(),
      'diagnosis': _diagnosis.text.trim(),
      'treatment': _treatment.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: const [
                Icon(Icons.medical_services_outlined,
                    color: Color(0xFF0D3B73), size: 22),
                SizedBox(width: 10),
                Text('Nueva entrada médica',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2545))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _sheetLabel('Fecha'),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Text(_dateFmt.format(_date),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0B2545),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _sheetLabel('Título *'),
                _sheetInput(_title, 'Ej. Revisión por vómitos'),
                const SizedBox(height: 14),
                _sheetLabel('Veterinario o clínica'),
                _sheetInput(_vet, 'Nombre del veterinario'),
                const SizedBox(height: 14),
                _sheetLabel('Descripción *'),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Síntomas u observaciones...',
                    hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),
                _sheetLabel('Diagnóstico'),
                _sheetInput(_diagnosis, 'Ej. Gastroenteritis'),
                const SizedBox(height: 14),
                _sheetLabel('Tratamiento'),
                _sheetInput(_treatment, 'Medicamentos, dosis...'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D3B73),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: _save,
                        child: const Text('Agregar',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0B2545))),
      );

  Widget _sheetInput(TextEditingController c, String hint) => TextField(
        controller: c,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          fillColor: Colors.white,
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE BOTTOM SHEET — Añadir vacuna
// ─────────────────────────────────────────────────────────────────────────────
class _InlineVaccineSheet extends StatefulWidget {
  const _InlineVaccineSheet();
  @override
  State<_InlineVaccineSheet> createState() => _InlineVaccineSheetState();
}

class _InlineVaccineSheetState extends State<_InlineVaccineSheet> {
  String _selectedVaccine = 'Rabia';
  DateTime _appliedDate = DateTime.now();
  DateTime? _nextDate;
  final _notes = TextEditingController();

  static const _vaccines = [
    'Rabia',
    'Parvovirus',
    'Desparasitación',
    'Moquillo',
    'Polivalente (Séxtuple)',
    'Otro tratamiento',
  ];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickApplied() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _appliedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _appliedDate = d);
  }

  Future<void> _pickNext() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _appliedDate.add(const Duration(days: 365)),
      firstDate: _appliedDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d != null) setState(() => _nextDate = d);
  }

  void _save() {
    Navigator.pop(context, {
      'name': _selectedVaccine,
      'appliedAt': _appliedDate,
      'nextDate': _nextDate,
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: const [
                Icon(Icons.vaccines_outlined,
                    color: Color(0xFF0D3B73), size: 22),
                SizedBox(width: 10),
                Text('Registrar vacuna',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2545))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _sheetLabel('Vacuna aplicada'),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVaccine,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF0F2B48)),
                      items: _vaccines
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F2B48),
                                      fontSize: 14))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedVaccine = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sheetLabel('Fecha de aplicación'),
                _dateTile(_appliedDate, _pickApplied),
                const SizedBox(height: 16),
                _sheetLabel('Próxima dosis (opcional)'),
                _dateTile(
                    _nextDate, _pickNext, 'Selecciona una fecha'),
                const SizedBox(height: 16),
                _sheetLabel('Notas (opcional)'),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ej. Lote, veterinario o reacciones',
                    hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D3B73),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: _save,
                        child: const Text('Agregar',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0B2545))),
      );

  Widget _dateTile(DateTime? date, VoidCallback onTap,
      [String placeholder = '']) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 10),
            Text(
              date != null ? _dateFmt.format(date) : placeholder,
              style: TextStyle(
                fontWeight: date != null ? FontWeight.w700 : FontWeight.w500,
                color: date != null
                    ? const Color(0xFF0B2545)
                    : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
