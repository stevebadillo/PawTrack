// ============================================================================
// SERVICIO DE AVATARES AUTOMÁTICOS (DiceBear)
// Genera avatares únicos a partir de una "semilla" (uid, id del perro, etc.)
// usando la API pública y gratuita de DiceBear: https://www.dicebear.com
//
// - No requiere clave de API ni registro.
// - La misma semilla siempre produce el mismo avatar, así que no hace falta
//   guardar la imagen: basta con guardar (o derivar) la semilla.
// - Se pide formato PNG porque Flutter no renderiza SVG sin un paquete extra.
// - Licencia: el código de DiceBear es MIT; cada estilo tiene su propia
//   licencia de diseño (los usados aquí permiten uso libre con atribución).
// ============================================================================
import '../models/models.dart';

class AvatarService {
  AvatarService._();

  static const String _baseUrl = 'https://api.dicebear.com/9.x';

  /// Estilos que el usuario puede elegir para su perfil.
  static const List<String> userStyles = ['critters', 'fun-emoji', 'thumbs'];

  /// Estilo por defecto para perfiles de usuario.
  static const String defaultUserStyle = 'critters';

  /// Estilo usado para los perros que todavía no tienen foto.
  static const String dogStyle = 'thumbs';

  /// Colores de fondo (hex sin '#') en la paleta azul/naranja de PawTrack.
  static const List<String> _dogBackgrounds = ['d0e0ff', 'ffe1d2', 'c7f0db', 'fdf0c4'];

  static bool isValidUserStyle(String? style) =>
      style != null && userStyles.contains(style);

  /// Construye la URL de un avatar DiceBear.
  ///
  /// [size] está en píxeles (DiceBear acepta de 1 a 256 en PNG).
  static String url({
    required String style,
    required String seed,
    int size = 160,
    List<String> backgroundColors = const [],
  }) {
    final safeSize = size.clamp(16, 256);
    final params = <String, String>{
      'seed': seed.isEmpty ? 'pawtrack' : seed,
      'size': '$safeSize',
      if (backgroundColors.isNotEmpty)
        'backgroundColor': backgroundColors.join(','),
    };
    return Uri.parse('$_baseUrl/$style/png')
        .replace(queryParameters: params)
        .toString();
  }

  /// Avatar de un usuario con el estilo y la semilla que tenga guardados.
  static String userAvatarUrl({
    required String seed,
    String? style,
    int size = 160,
  }) =>
      url(
        style: isValidUserStyle(style) ? style! : defaultUserStyle,
        seed: seed,
        size: size,
      );

  /// Avatar automático para un perro sin foto. Usa el id del documento como
  /// semilla, así el avatar no cambia aunque se edite el nombre.
  static String dogAvatarUrl(Dog dog, {int size = 160}) => url(
        style: dogStyle,
        seed: dog.id.isNotEmpty ? dog.id : dog.name,
        size: size,
        backgroundColors: _dogBackgrounds,
      );
}
