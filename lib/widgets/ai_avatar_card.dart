import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/ai_avatar_service.dart';
import '../services/avatar_service.dart';

/// Tarjeta de la ficha del perro con su avatar caricatura generado por IA.
/// El personal puede generarlo o regenerarlo; el resto solo lo ve si existe.
class AiAvatarCard extends StatefulWidget {
  final Dog dog;
  final bool canGenerate;
  const AiAvatarCard({super.key, required this.dog, required this.canGenerate});

  @override
  State<AiAvatarCard> createState() => _AiAvatarCardState();
}

class _AiAvatarCardState extends State<AiAvatarCard> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AiAvatarService.generateAndSave(widget.dog);
      messenger.showSnackBar(
          const SnackBar(content: Text('Avatar con IA guardado.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dog = widget.dog;
    final hasAvatar = dog.aiAvatarUrl.isNotEmpty;
    if (!hasAvatar && !widget.canGenerate) return const SizedBox.shrink();

    final fromPhoto = AiAvatarService.usesPhoto(dog);
    final subtitle = hasAvatar
        ? 'Caricatura generada con Pollinations.AI'
        : fromPhoto
            ? 'Se generará a partir de la foto del perro.'
            : 'Se generará con sus rasgos (color, sexo, raza estimada).';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: SizedBox(
            width: 80,
            height: 80,
            child: _generating
                ? const ColoredBox(
                    color: Color(0xFFF1F5FB),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Image.network(
                    hasAvatar
                        ? dog.aiAvatarUrl
                        : AvatarService.dogAvatarUrl(dog, size: 160),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFF1F5FB),
                      child: Icon(Icons.pets, color: Color(0xFF93C5FD)),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.auto_awesome, size: 18, color: Color(0xFF0D3B73)),
              SizedBox(width: 8),
              Text('Avatar con IA',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B2545))),
            ]),
            const SizedBox(height: 4),
            Text(_generating ? 'Generando… puede tardar hasta un minuto.' : subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (widget.canGenerate) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(hasAvatar ? 'Regenerar' : 'Generar avatar'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
