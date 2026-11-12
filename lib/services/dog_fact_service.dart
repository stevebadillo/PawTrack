import 'dart:convert';
import 'package:http/http.dart' as http;

class DogFactService {
  static const String _endpoint = 'https://dogapi.dog/api/v2/facts';

  // Colección de datos y recomendaciones educativas en español
  // para enriquecer la experiencia y asegurar datos siempre disponibles
  static final List<String> _localEducationFacts = [
    'Los perros tienen un sentido del olfato entre 10.000 y 100.000 veces más agudo que el de los humanos.',
    'Cada perro tiene una huella nasal única, tan individual como las huellas dactilares de las personas.',
    'El bostezo en los perros no siempre indica sueño; a menudo es una señal de calma para reducir el estrés o tensión.',
    'Los caninos pueden oír frecuencias de hasta 45.000 Hz, casi el doble de lo que percibe el oído humano.',
    'Mover la cola hacia la derecha suele asociarse con emociones positivas, mientras que a la izquierda puede indicar cautela o inseguridad.',
    'Los perros sudan principalmente a través de las almohadillas de sus patas y regulan su temperatura jadeando.',
    'El chocolate contiene teobromina, un compuesto que los perros metabolizan muy lentamente y que resulta tóxico para ellos.',
    'Los cachorros nacen sordos y ciegos; desarrollan sus sentidos de la vista y oído alrededor de las dos a tres semanas de vida.',
    'La esterilización oportuna ayuda a prevenir enfermedades graves y controla de forma compasiva la sobrepoblación canina.',
    'Nunca debes dar ibuprofeno ni paracetamol a un perro sin prescripción veterinaria, ya que pueden provocar fallas renales o hepáticas.',
  ];

  /// Obtiene un dato curioso desde Dog Facts API con respaldo educativo
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
            return factBody.toString();
          }
        }
      }
    } catch (_) {
      // Si la API externa no responde o falla la red, usamos el catálogo educativo
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
        'desc': 'Evita darles huesos cocidos o restos de comida con condimentos; pueden dañar su estómago.',
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
