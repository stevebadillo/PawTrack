import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class VaccineFormScreen extends StatefulWidget {
  final Dog? dog;
  final String? dogName;
  const VaccineFormScreen({super.key, this.dog, this.dogName});

  @override
  State<VaccineFormScreen> createState() => _VaccineFormScreenState();
}

class _VaccineFormScreenState extends State<VaccineFormScreen> {
  String _selectedVaccine = 'Rabia';
  DateTime _appliedDate = DateTime.now();
  DateTime? _nextDate;
  final _notes = TextEditingController();
  bool _saving = false;

  final _fmt = DateFormat('dd/MM/yyyy');

  final List<String> _vaccines = [
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

  Future<void> _pickAppliedDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _appliedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _appliedDate = d);
  }

Future<void> _pickNextDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _appliedDate.add(const Duration(days: 365)),
      firstDate: _appliedDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d == null) return;

    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (t == null) return;

    setState(() {
      _nextDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final vaccineData = {
        'name': _selectedVaccine,
        'appliedAt': _appliedDate,
        'nextDate': _nextDate, // Ya contiene fecha y hora (DateTime) para Google Calendar
        'notes': _notes.text.trim(),
      };

      if (widget.dog != null) {
        await DataService.addVaccine(
          widget.dog!.id,
          _selectedVaccine,
          _appliedDate,
          _nextDate,
          _notes.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vacuna registrada correctamente.')),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          Navigator.pop(context, vaccineData);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar vacuna: $e')),
        );
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
                      child: Icon(Icons.chevron_left_rounded, color: Color(0xFF0F2B48), size: 26),
                    ),
                  ),
                ),
                const Text(
                  'Registrar vacuna',
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
          // Dog Mini Card (Warm beige)
          if (widget.dog != null || (widget.dogName != null && widget.dogName!.isNotEmpty))
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE7C7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD69E66),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.pets, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Perro',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        widget.dog?.name ?? widget.dogName ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0B2545)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 1. Vacuna aplicada Dropdown
          const Text(
            'Vacuna aplicada',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedVaccine,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F2B48)),
                items: _vaccines.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(
                      v,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F2B48), fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedVaccine = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Fecha de aplicación
          const Text(
            'Fecha de aplicación',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickAppliedDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                _fmt.format(_appliedDate),
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0B2545), fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Próxima dosis (opcional)
          const Row(
            children: [
              Text(
                'Próxima dosis ',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
              ),
              Text(
                '(opcional)',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickNextDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                _nextDate != null ? _fmt.format(_nextDate!) : 'dd/mm/aaaa',
                style: TextStyle(
                  fontWeight: _nextDate != null ? FontWeight.w800 : FontWeight.w500,
                  color: _nextDate != null ? const Color(0xFF0B2545) : const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Notas (opcional)
          const Row(
            children: [
              Text(
                'Notas ',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
              ),
              Text(
                '(opcional)',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Ej. Lote, veterinario o reacciones',
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B73),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar vacuna', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

