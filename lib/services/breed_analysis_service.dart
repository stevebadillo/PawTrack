import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

class BreedAnalysisService {
  static const _endpoint =
      'https://pawtrack-breed-api.steveajedrez5.workers.dev/';

  static Future<List<BreedPrediction>> analyze(Uint8List image) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Inicia sesión para analizar la foto.');

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'imageBase64': base64Encode(image)}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo analizar la foto (${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    final raw = data is Map<String, dynamic> ? data['breeds'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => BreedPrediction.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }
}
