import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

final _fmt = DateFormat('dd/MM/yyyy');

/// Detalle del perro + historial de vacunación (RF06, RF07).
class DogDetailScreen extends StatelessWidget {
  final String dogId;
  final AppUser user;
  const DogDetailScreen({super.key, required this.dogId, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Dog>(
      stream: DataService.dog(dogId),
      builder: (context, snap) {
        if (snap.hasError)
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
                child: Text('No se pudo cargar la ficha del perro.')),
          );
        if (!snap.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        final d = snap.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(d.name),
            actions: [
              if (user.isStaff)
                IconButton(
                  tooltip: 'Eliminar perro',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmDogDeletion(context, d),
                ),
            ],
          ),
          floatingActionButton: user.isStaff
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.vaccines),
                  label: const Text('Añadir vacuna'),
                  onPressed: () => showDialog(
                      context: context,
                      builder: (_) => _VaccineDialog(dogId: dogId)),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              if (d.photoUrl.isNotEmpty)
                Image.network(d.photoUrl,
                    height: 240,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder())
              else
                _photoPlaceholder(),
              ListTile(
                  leading: const Icon(Icons.pets),
                  title: const Text('Sexo'),
                  trailing: Text(d.sex)),
              ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Color'),
                  trailing: Text(d.color)),
              ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: const Text('Collar rojo'),
                  trailing: Text(d.hasRedCollar ? 'Sí' : 'No')),
              if (d.description.isNotEmpty)
                ListTile(
                    title: const Text('Descripción'),
                    subtitle: Text(d.description)),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Historial de vacunación',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              StreamBuilder<List<Vaccine>>(
                stream: DataService.vaccines(dogId),
                builder: (context, vs) {
                  if (vs.hasError)
                    return const ListTile(
                        title:
                            Text('No se pudo cargar el historial de vacunas.'));
                  if (!vs.hasData) return const LinearProgressIndicator();
                  if (vs.data!.isEmpty)
                    return const ListTile(
                        title: Text('Sin vacunas registradas'));
                  return Column(
                    children: [
                      for (final v in vs.data!)
                        ListTile(
                          leading: const Icon(Icons.vaccines),
                          title: Text(v.name),
                          subtitle: Text('Aplicada: ${_fmt.format(v.appliedAt)}'
                              '${v.nextDate != null ? '\nPróxima: ${_fmt.format(v.nextDate!)}' : ''}'
                              '${v.notes.isNotEmpty ? '\n${v.notes}' : ''}'),
                          isThreeLine: v.nextDate != null,
                          trailing: v.nextDate != null &&
                                  v.nextDate!.isBefore(DateTime.now())
                              ? const Chip(label: Text('Vencida'))
                              : null,
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

  Widget _photoPlaceholder() => Container(
        height: 220,
        color: const Color(0xFFF2F4F7),
        child: const Center(
            child: Icon(Icons.pets, size: 76, color: Color(0xFF9AA4B2))),
      );
}

Future<void> _confirmDogDeletion(BuildContext context, Dog dog) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded),
      title: Text('Eliminar a ${dog.name}?'),
      content: const Text(
        'Se eliminará su ficha y su historial de vacunas. Los reportes anteriores se conservarán con el nombre del perro.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar perro'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await DataService.deleteDog(dog);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${dog.name} se eliminó del catálogo.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se pudo eliminar. Revisa tu conexión e inténtalo de nuevo.'),
        ),
      );
    }
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

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2040));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva vacuna'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _name,
              decoration:
                  const InputDecoration(labelText: 'Vacuna (ej. Antirrábica)')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha aplicada'),
            subtitle: Text(_fmt.format(_applied)),
            onTap: () async {
              final d = await _pickDate(_applied);
              if (d != null) setState(() => _applied = d);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Próxima dosis'),
            subtitle: Text(_next == null ? 'Sin definir' : _fmt.format(_next!)),
            onTap: () async {
              final d = await _pickDate(
                  DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _next = d);
            },
          ),
          TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notas')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().isEmpty || _saving) return;
            setState(() => _saving = true);
            try {
              await DataService.addVaccine(widget.dogId, _name.text.trim(),
                  _applied, _next, _notes.text.trim());
              if (context.mounted) Navigator.pop(context);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'No se pudo guardar la vacuna. Revisa tu conexión e inténtalo de nuevo.')),
                );
                setState(() => _saving = false);
              }
            }
          },
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
