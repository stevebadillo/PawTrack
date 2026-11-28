import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/avatar_service.dart';

/// Muestra la imagen del perro con este orden de respaldo:
/// foto real → avatar IA (Pollinations, si ya se generó) → avatar DiceBear →
/// ícono de huella (sin conexión). Cada paso se usa si el anterior no existe
/// o falla al cargar.
class DogAvatar extends StatelessWidget {
  final Dog dog;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const DogAvatar({
    super.key,
    required this.dog,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    final pixelSize =
        (width > height ? width : height) * MediaQuery.devicePixelRatioOf(context);
    final generatedUrl =
        AvatarService.dogAvatarUrl(dog, size: pixelSize.round());

    Widget generated() => Image.network(
          generatedUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(context),
        );

    Widget aiOrGenerated() => dog.aiAvatarUrl.isEmpty
        ? generated()
        : Image.network(
            dog.aiAvatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => generated(),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: dog.photoUrl.isEmpty
            ? aiOrGenerated()
            : Image.network(
                dog.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => aiOrGenerated(),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(Icons.pets_rounded,
          color: colors.onSecondaryContainer, size: width * 0.4),
    );
  }
}
