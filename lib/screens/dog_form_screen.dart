import 'dart:typed_data';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/breed_analysis_service.dart';
import '../widgets/breed_analysis_card.dart';
import 'dog_detail_screen.dart';
import 'medical_entry_screen.dart';
import 'vaccine_form_screen.dart';

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
  List<BreedPrediction> _breedAnalysis = const [];
  bool _analyzingBreed = false;

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
        if (mounted) setState(() { _photo = bytes; _breedAnalysis = const []; _analyzingBreed = true; });
        try {
          final breeds = await BreedAnalysisService.analyze(bytes);
          if (mounted) setState(() => _breedAnalysis = breeds);
        } catch (error) {
          // Breed recognition is optional. Keep the photo and let staff choose
          // the breed manually when Nakordoni is unavailable.
          debugPrint('Breed analysis unavailable: $error');
        } finally {
          if (mounted) setState(() => _analyzingBreed = false);
        }
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

  // ── Medical entry screen navigation ──
  Future<void> _addMedicalEntry() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicalEntryScreen(dogName: _name.text.trim()),
      ),
    );
    if (result != null && mounted) {
      setState(() => _medicalEntries.add(result));
    }
  }

  // ── Vaccine screen navigation ──
  Future<void> _addVaccineEntry() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => VaccineFormScreen(dogName: _name.text.trim()),
      ),
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
        if (_photo != null)
          'breedAnalysis': _breedAnalysis.map((breed) => breed.toMap()).toList(),
        if (_photo != null && _breedAnalysis.isNotEmpty)
          'breedAnalyzedAt': FieldValue.serverTimestamp(),
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
                'documents':
                    _medicalEntries.first['documents'] as List<String>? ??
                        const <String>[],
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
            'documents': e['documents'] ?? const <String>[],
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
            'El almacenamiento no está configurado en Firebase.',
          FirebaseException(code: 'unauthorized' || 'unauthenticated') =>
            'Acceso denegado. Revisa que la sesión esté activa.',
          TimeoutException() =>
            'La subida de la imagen tardó demasiado. Comprueba tu conexión.',
          ArgumentError() =>
            error.toString().replaceFirst('Invalid argument(s): ', ''),
          _ => error.toString().replaceFirst('Exception: ', ''),
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
            if (_analyzingBreed) ...[
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Center(child: Text('Analizando posibles razas…')),
              ),
            ],
            if (_breedAnalysis.isNotEmpty)
              BreedAnalysisCard(breeds: _breedAnalysis),
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
                  onRemove: () => setState(() => _medicalEntries.removeAt(i)),
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
                  onRemove: () => setState(() => _vaccineEntries.removeAt(i)),
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
              onPressed: (_saving || _analyzingBreed) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
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
                        child: Icon(Icons.check, size: 16, color: Colors.white),
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
