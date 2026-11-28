import 'package:flutter_test/flutter_test.dart';
import 'package:pawtrack/models/models.dart';
import 'package:pawtrack/services/avatar_service.dart';

Dog _dog({String id = 'abc123', String name = 'Firulais'}) => Dog(
      id: id,
      name: name,
      sex: 'Macho',
      color: 'Café',
      description: '',
      photoUrl: '',
      hasRedCollar: false,
      createdAt: DateTime(2026),
    );

void main() {
  test('la misma semilla genera la misma URL', () {
    expect(AvatarService.dogAvatarUrl(_dog()), AvatarService.dogAvatarUrl(_dog()));
  });

  test('el avatar del perro usa su id, no su nombre', () {
    final uri = Uri.parse(AvatarService.dogAvatarUrl(_dog(name: 'Otro')));
    expect(uri.host, 'api.dicebear.com');
    expect(uri.path, '/9.x/thumbs/png');
    expect(uri.queryParameters['seed'], 'abc123');
  });

  test('un estilo de usuario inválido vuelve al estilo por defecto', () {
    final uri = Uri.parse(
        AvatarService.userAvatarUrl(seed: 'uid', style: 'no-existe'));
    expect(uri.path, '/9.x/${AvatarService.defaultUserStyle}/png');
  });

  test('codifica semillas con espacios y limita el tamaño', () {
    final uri = Uri.parse(AvatarService.url(
        style: 'critters', seed: 'juan pérez@mail.com', size: 1000));
    expect(uri.queryParameters['seed'], 'juan pérez@mail.com');
    expect(uri.queryParameters['size'], '256');
  });
}
