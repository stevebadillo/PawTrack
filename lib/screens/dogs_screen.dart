import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'dog_detail_screen.dart';
import 'dog_form_screen.dart';

class DogsScreen extends StatefulWidget {
  final AppUser user;
  const DogsScreen({super.key, required this.user});
  @override
  State<DogsScreen> createState() => _DogsScreenState();
}

class _DogsScreenState extends State<DogsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _deleteDog(BuildContext context, Dog dog) async {
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
            style: FilledButton.styleFrom(foregroundColor: Colors.red.shade800),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${dog.name} se eliminó del catálogo.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se pudo eliminar. Revisa que tu cuenta tenga el rol Personal y vuelve a intentarlo.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<List<Dog>>(
      stream: DataService.dogs(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _DogsMessage(
            icon: Icons.cloud_off_outlined,
            title: 'No se pudo cargar el catálogo',
            message: 'Comprueba la conexión a internet e inténtalo de nuevo.',
          );
        }
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final dogs = snap.data!;
        final filtered = dogs.where((dog) {
          final query = _query.toLowerCase();
          return dog.name.toLowerCase().contains(query) ||
              dog.color.toLowerCase().contains(query) ||
              dog.description.toLowerCase().contains(query);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 112),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Perros del campus',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                          '${dogs.length} ${dogs.length == 1 ? 'perro registrado' : 'perros registrados'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (widget.user.isStaff)
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DogFormScreen())),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir'),
                  ),
              ],
            ),
            if (dogs.isNotEmpty) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o rasgos',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (dogs.isEmpty)
              SizedBox(
                height: 330,
                child: _DogsMessage(
                  icon: Icons.pets_rounded,
                  title: 'El catálogo está empezando',
                  message: widget.user.isStaff
                      ? 'Registra al primer perro para que aparezca en los reportes.'
                      : 'El personal irá agregando los perros que viven en el campus.',
                  action: widget.user.isStaff
                      ? FilledButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DogFormScreen())),
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar primer perro'),
                        )
                      : null,
                ),
              )
            else if (filtered.isEmpty)
              const SizedBox(
                height: 220,
                child: _DogsMessage(
                  icon: Icons.search_off,
                  title: 'No encontramos coincidencias',
                  message: 'Prueba con otro nombre o color.',
                ),
              )
            else
              for (final dog in filtered)
                _DogCard(
                  dog: dog,
                  canDelete: widget.user.isStaff,
                  onDelete: () => _deleteDog(context, dog),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            DogDetailScreen(dogId: dog.id, user: widget.user)),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _DogCard extends StatelessWidget {
  final Dog dog;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool canDelete;
  const _DogCard(
      {required this.dog,
      required this.onTap,
      required this.onDelete,
      required this.canDelete});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: dog.photoUrl.isEmpty
                      ? ColoredBox(
                          color: colors.secondaryContainer,
                          child: Icon(Icons.pets_rounded,
                              color: colors.onSecondaryContainer, size: 32),
                        )
                      : Image.network(
                          dog.photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: colors.secondaryContainer,
                            child: Icon(Icons.pets_rounded,
                                color: colors.onSecondaryContainer, size: 32),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dog.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                        [dog.sex, if (dog.color.isNotEmpty) dog.color]
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    if (dog.hasRedCollar) ...[
                      const SizedBox(height: 8),
                      const _Tag(icon: Icons.circle, label: 'Collar rojo'),
                    ],
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Eliminar perro',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: colors.error,
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 8, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 5),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}

class _DogsMessage extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Widget? action;
  const _DogsMessage(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 52, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.4)),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      );
}
