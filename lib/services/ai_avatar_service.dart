// ============================================================================
// AVATAR CON IA (Pollinations.AI)
// - Perfil (Ajustes → Personalizar avatar → Crear avatar con IA): el usuario
//   sube una foto y se convierte en caricatura con model=kontext (necesita
//   POLLINATIONS_KEY). Ver avatarFromPhoto().
// - Perros: genera un avatar caricatura y lo guarda en su ficha.
//
// Dos modos, según haya o no clave:
// 1. Sin clave (respaldo si se deja la clave vacía): usa la API clásica
//    https://image.pollinations.ai/prompt/{prompt}. Es texto→imagen: el
//    prompt se arma con los datos del perro (color, sexo, raza estimada,
//    collar), no lee la foto. Límite aprox.: 1 petición cada ~45 s por IP.
// 2. Con clave (ya viene puesta en [apiKey], no hay que configurar nada):
//    usa https://gen.pollinations.ai/image/{prompt} con model=kontext y la
//    foto del perro como referencia (imagen→imagen), así el avatar se parece
//    al perro real. Consume "pollen" de tu cuenta en enter.pollinations.ai.
//
// La imagen resultante se sube a Cloudinary (DataService.uploadPhoto) para no
// volver a generarla cada vez que alguien abre la ficha. Si algo falla, la app
// sigue mostrando la foto o el avatar de DiceBear (ver DogAvatar).
// ============================================================================
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'data_service.dart';

class AiAvatarException implements Exception {
  final String message;
  const AiAvatarException(this.message);
  @override
  String toString() => message;
}

class AiAvatarService {
  AiAvatarService._();

  /// Clave de Pollinations. Viene puesta por defecto para que la app funcione
  /// con solo darle Run; se puede cambiar con --dart-define=POLLINATIONS_KEY=...
  static const String apiKey = String.fromEnvironment(
    'POLLINATIONS_KEY',
    defaultValue: 'sk_e7CoEUljV71HbcQfXGOBLRlScL3eNgIw',
  );
  static const String _classicBase = 'https://image.pollinations.ai/prompt';
  static const String _genBase = 'https://gen.pollinations.ai/image';
  static const int _size = 512;

  /// true si hay clave y foto: el avatar se generará a partir de la foto.
  static bool usesPhoto(Dog dog) => apiKey.isNotEmpty && dog.photoUrl.isNotEmpty;

  /// Prompt en inglés (los modelos responden mejor) con los rasgos del perro.
  static String buildPrompt(Dog dog, {bool fromPhoto = false}) {
    if (fromPhoto) {
      return 'Turn this dog photo into a cute cartoon avatar, keep the same '
          'dog, fur colors and markings, head and shoulders portrait, '
          'centered, soft pastel blue background, clean flat illustration, '
          'no text';
    }
    final traits = <String>[
      if (dog.color.trim().isNotEmpty) '${dog.color.trim()} colored fur',
      dog.sex.toLowerCase().startsWith('h') ? 'female' : 'male',
      if (dog.breedAnalysis.isNotEmpty) '${dog.breedAnalysis.first.name} mix',
      if (dog.hasRedCollar) 'wearing a red collar',
    ];
    return 'Cute cartoon avatar of a friendly street dog, ${traits.join(', ')}, '
        'head and shoulders portrait, centered, soft pastel blue background, '
        'clean flat illustration, no text';
  }

  /// Semilla estable por perro para que el resultado sea reproducible.
  static int seedFor(Dog dog) => dog.id.hashCode.abs() % 1000000;

  /// URL de la petición a Pollinations (sin la clave, que va en la cabecera).
  static Uri requestUri(Dog dog) {
    final fromPhoto = usesPhoto(dog);
    final prompt = Uri.encodeComponent(buildPrompt(dog, fromPhoto: fromPhoto));
    final params = <String, String>{
      'width': '$_size',
      'height': '$_size',
      'seed': '${seedFor(dog)}',
      'nologo': 'true',
      if (fromPhoto) 'model': 'kontext',
      if (fromPhoto) 'image': dog.photoUrl,
    };
    final base = fromPhoto ? _genBase : _classicBase;
    return Uri.parse('$base/$prompt').replace(queryParameters: params);
  }

  /// Pide la imagen a Pollinations y devuelve los bytes.
  static Future<Uint8List> generate(Dog dog, {http.Client? client}) =>
      _fetchImage(requestUri(dog), auth: usesPhoto(dog), client: client);

  /// Prompt para convertir una foto de perfil en avatar caricatura.
  static const String profilePrompt =
      'Turn the person or pet in this photo into a cute cartoon avatar, keep '
      'the same face features, hair or fur colors and expression, head and '
      'shoulders portrait, centered, soft pastel blue background, clean flat '
      'illustration, no text';

  /// URL de imagen→imagen (kontext) con una foto pública como referencia.
  static Uri photoToAvatarUri(String photoUrl, {int seed = 0}) => Uri.parse(
          '$_genBase/${Uri.encodeComponent(profilePrompt)}')
      .replace(queryParameters: {
        'model': 'kontext',
        'image': photoUrl,
        'width': '$_size',
        'height': '$_size',
        'seed': '$seed',
        'nologo': 'true',
      });

  /// Convierte la foto de perfil subida por el usuario en un avatar con IA.
  ///
  /// Pollinations necesita la foto en una URL pública, así que primero se sube
  /// a Cloudinary ([upload] permite reemplazarlo en pruebas). Requiere
  /// POLLINATIONS_KEY porque imagen→imagen no está en el plan sin clave.
  static Future<Uint8List> avatarFromPhoto(
    Uint8List photo, {
    http.Client? client,
    Future<String> Function(Uint8List bytes)? upload,
  }) async {
    if (apiKey.isEmpty) {
      throw const AiAvatarException(
          'Falta la clave de Pollinations. Ejecuta la app con --dart-define=POLLINATIONS_KEY=...');
    }
    final String photoUrl;
    try {
      photoUrl = await (upload ??
          (b) => DataService.uploadPhoto(b, 'perfiles_origen_ia'))(photo);
    } catch (e) {
      throw AiAvatarException('No se pudo subir la foto: $e');
    }
    final seed = DateTime.now().millisecondsSinceEpoch % 1000000;
    return _fetchImage(photoToAvatarUri(photoUrl, seed: seed),
        auth: true, client: client);
  }

  static Future<Uint8List> _fetchImage(Uri uri,
      {required bool auth, http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c.get(uri, headers: {
        if (auth) 'Authorization': 'Bearer $apiKey',
      }).timeout(const Duration(seconds: 120),
          onTimeout: () => throw const AiAvatarException(
              'Pollinations tardó demasiado. Intenta de nuevo en un momento.'));

      switch (res.statusCode) {
        case 200:
          break;
        case 401:
        case 403:
          throw const AiAvatarException(
              'Pollinations rechazó la clave. Revisa POLLINATIONS_KEY.');
        case 402:
          throw const AiAvatarException(
              'Tu cuenta de Pollinations no tiene créditos suficientes.');
        case 429:
          throw const AiAvatarException(
              'Pollinations está limitando las peticiones. Espera un minuto y vuelve a intentar.');
        default:
          throw AiAvatarException(
              'Pollinations respondió con error ${res.statusCode}.');
      }
      final type = res.headers['content-type'] ?? '';
      if (!type.startsWith('image/') || res.bodyBytes.isEmpty) {
        throw const AiAvatarException('Pollinations no devolvió una imagen.');
      }
      return res.bodyBytes;
    } on AiAvatarException {
      rethrow;
    } catch (e) {
      throw AiAvatarException('No se pudo conectar con Pollinations: $e');
    } finally {
      if (client == null) c.close();
    }
  }

  /// Genera el avatar, lo sube y lo guarda en la ficha (`aiAvatarUrl`).
  /// Devuelve la URL pública guardada.
  static Future<String> generateAndSave(Dog dog) async {
    final bytes = await generate(dog);
    final url = await DataService.uploadPhoto(
      bytes,
      'avatares_ia',
      filename: 'avatar_${dog.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await DataService.updateDog(dog.id, {'aiAvatarUrl': url});
    return url;
  }
}
