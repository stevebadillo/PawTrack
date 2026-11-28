import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawtrack/models/models.dart';
import 'package:pawtrack/services/ai_avatar_service.dart';

Dog _dog({String photoUrl = ''}) => Dog(
      id: 'abc123',
      name: 'Firulais',
      sex: 'Hembra',
      color: 'Café',
      description: '',
      photoUrl: photoUrl,
      hasRedCollar: true,
      createdAt: DateTime(2026),
      breedAnalysis: const [BreedPrediction(id: 'b', name: 'Labrador', score: .8)],
    );

void main() {
  test('sin clave usa la API clásica gratuita con los rasgos del perro', () {
    if (AiAvatarService.apiKey.isNotEmpty) return;
    final uri = AiAvatarService.requestUri(_dog(photoUrl: 'https://x/foto.jpg'));
    expect(uri.host, 'image.pollinations.ai');
    expect(uri.queryParameters.containsKey('image'), isFalse);
    final prompt = uri.pathSegments.last;
    expect(prompt, contains('Café'));
    expect(prompt, contains('female'));
    expect(prompt, contains('Labrador'));
    expect(prompt, contains('red collar'));
    expect(uri.queryParameters['seed'], '${AiAvatarService.seedFor(_dog())}');
  });

  test('devuelve los bytes cuando Pollinations responde una imagen', () async {
    final client = MockClient((_) async => http.Response.bytes(
        [1, 2, 3], 200, headers: {'content-type': 'image/jpeg'}));
    final bytes = await AiAvatarService.generate(_dog(), client: client);
    expect(bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('traduce el límite de peticiones a un mensaje claro', () async {
    final client = MockClient((_) async => http.Response('slow down', 429));
    expect(AiAvatarService.generate(_dog(), client: client),
        throwsA(isA<AiAvatarException>()));
  });

  test('rechaza respuestas que no son imagen', () async {
    final client = MockClient((_) async =>
        http.Response('{}', 200, headers: {'content-type': 'application/json'}));
    expect(AiAvatarService.generate(_dog(), client: client),
        throwsA(isA<AiAvatarException>()));
  });

  test('el avatar de perfil usa kontext con la foto subida como referencia', () {
    final uri = AiAvatarService.photoToAvatarUri('https://res.cloudinary.com/x/foto.jpg', seed: 7);
    expect(uri.host, 'gen.pollinations.ai');
    expect(uri.queryParameters['model'], 'kontext');
    expect(uri.queryParameters['image'], 'https://res.cloudinary.com/x/foto.jpg');
    expect(uri.queryParameters['seed'], '7');
  });

  test('sin clave avisa que falta POLLINATIONS_KEY', () async {
    if (AiAvatarService.apiKey.isNotEmpty) return;
    expect(
        AiAvatarService.avatarFromPhoto(Uint8List.fromList([1]),
            upload: (_) async => 'https://x/foto.jpg'),
        throwsA(isA<AiAvatarException>()));
  });

  test('con clave sube la foto y devuelve el avatar', () async {
    if (AiAvatarService.apiKey.isEmpty) return; // corre con --dart-define
    Uri? pedido;
    final client = MockClient((req) async {
      pedido = req.url;
      return http.Response.bytes([9], 200, headers: {'content-type': 'image/jpeg'});
    });
    final bytes = await AiAvatarService.avatarFromPhoto(Uint8List.fromList([1]),
        client: client, upload: (_) async => 'https://x/foto.jpg');
    expect(bytes, Uint8List.fromList([9]));
    expect(pedido!.queryParameters['image'], 'https://x/foto.jpg');
  });
}
