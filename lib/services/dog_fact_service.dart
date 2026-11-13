import 'dart:convert';
import 'package:http/http.dart' as http;

class DogFactService {
  static const String _endpoint = 'https://dogapi.dog/api/v2/facts';

  // Catálogo completo de datos educativos y curiosidades caninas en español
  static final List<String> _localEducationFacts = [
    'Los perros tienen un sentido del olfato entre 10.000 y 100.000 veces más agudo que el de los seres humanos.',
    'Cada perro tiene una huella nasal totalmente única, equivalente a las huellas dactilares de las personas.',
    'El bostezo en los perros no siempre indica sueño; a menudo es una señal de calma para reducir la tensión o el estrés.',
    'Los caninos pueden escuchar frecuencias sonoras de hasta 45.000 Hz, casi el doble de lo que percibe el oído humano.',
    'Mover la cola hacia la derecha suele asociarse con emociones positivas, mientras que hacia la izquierda denota cautela o inseguridad.',
    'Los perros sudan a través de las almohadillas de sus patas y regulan la temperatura corporal jadeando.',
    'El chocolate contiene teobromina, un compuesto que los perros no pueden metabolizar y resulta altamente tóxico para ellos.',
    'Los cachorros nacen ciegos y sordos; desarrollan la vista y el oído aproximadamente a las tres semanas de vida.',
    'La esterilización oportuna previene tumores e infecciones graves y controla humanitariamente la sobrepoblación en el campus.',
    'Nunca debes administrar paracetamol ni ibuprofeno a un canino; les provoca insuficiencia renal y hepática severa.',
    'Los perros pueden aprender a reconocer más de 150 palabras, señales gestuales y comandos diferentes.',
    'El contacto visual cariñoso entre un perro y una persona libera oxitocina (la hormona del apego) en ambos.',
    'Un perro adulto tiene 42 dientes definitivos, mientras que los humanos tenemos 32.',
    'El sentido del oído de un perro es tan preciso que puede mover cada oreja de forma independiente para localizar el origen exacto del sonido.',
    'Los galgos son los perros más veloces del planeta, capaces de alcanzar velocidades de hasta 72 km/h en sprint.',
  ];

  /// Traduce texto en inglés a español usando MyMemory Translation API (100% gratuita)
  static Future<String?> _translateToSpanish(String text) async {
    try {
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|es',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final translated = data['responseData']?['translatedText'];
        if (translated != null &&
            translated.toString().trim().isNotEmpty &&
            !translated.toString().toUpperCase().contains('MYMEMORY WARNING')) {
          return translated.toString();
        }
      }
    } catch (_) {
      // Si la traducción externa falla, se retorna null para usar el catálogo en español
    }
    return null;
  }

  /// Obtiene un dato curioso desde Dog Facts API y lo traduce al español.
  /// Si la traducción o la API externa fallan, devuelve un dato del catálogo en español.
  static Future<String> fetchFact() async {
    try {
      final response = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List && (data['data'] as List).isNotEmpty) {
          final factBody = data['data'][0]['attributes']['body'];
          if (factBody != null && factBody.toString().trim().isNotEmpty) {
            final translated = await _translateToSpanish(factBody.toString());
            if (translated != null && translated.isNotEmpty) {
              return translated;
            }
          }
        }
      }
    } catch (_) {
      // Continuar con el respaldo en español
    }

    _localEducationFacts.shuffle();
    return _localEducationFacts.first;
  }

  /// Recomendaciones educativas y de cuidado animal en el campus
  static List<Map<String, String>> getRecommendations() {
    return [
      {
        'title': 'Acercamiento seguro',
        'desc': 'Permite que el can huela el dorso de tu mano cerrada antes de intentar acariciarlo.',
        'icon': 'pets',
      },
      {
        'title': 'Alimentación adecuada',
        'desc': 'Evita darles huesos cocidos o restos de comida con condimentos; dañan su estómago.',
        'icon': 'restaurant',
      },
      {
        'title': 'Respeto al descanso',
        'desc': 'Si un canino está durmiendo o comiendo dentro del campus, no lo molestes ni sorprendas.',
        'icon': 'hotel',
      },
      {
        'title': 'Collar rojo de atención',
        'desc': 'Los perros con collar rojo requieren mayor precaución o están en tratamiento médico.',
        'icon': 'health_and_safety',
      },
    ];
  }
}
