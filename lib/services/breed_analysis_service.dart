import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

class BreedAnalysisService {
  static const _endpoint =
      'https://pawtrack-breed-api.steveajedrez5.workers.dev/';

  static Future<List<BreedPrediction>> analyze(Uint8List image) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('Inicia sesión para analizar la foto.');

    // Nakordoni requires the shorter image side to be at least 200 px. Small
    // gallery images (including the 270x180 example) otherwise fail with 400.
    final imageForAnalysis = await _ensureMinimumSide(image, 200);

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'imageBase64': base64Encode(imageForAnalysis)}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var errorMessage = 'HTTP ${response.statusCode}';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map<String, dynamic>) {
          final upstreamStatus = errorBody['upstreamStatus'];
          final code = errorBody['code'];
          if (upstreamStatus != null || code != null) {
            errorMessage += ' · Nakordoni ${upstreamStatus ?? ''} ${code ?? ''}'.trim();
          } else if (errorBody['error'] is String) {
            errorMessage += ' · ${errorBody['error']}';
          }
        }
      } catch (_) {
        // Keep the HTTP status if the proxy didn't return JSON.
      }
      throw Exception(errorMessage);
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

  static Future<Uint8List> _ensureMinimumSide(
    Uint8List bytes,
    int minimumSide,
  ) async {
    final sourceCodec = await ui.instantiateImageCodec(bytes);
    final sourceFrame = await sourceCodec.getNextFrame();
    final width = sourceFrame.image.width;
    final height = sourceFrame.image.height;
    sourceFrame.image.dispose();
    sourceCodec.dispose();

    final shortestSide = width < height ? width : height;
    if (shortestSide >= minimumSide) return bytes;

    // Scale proportionally: this only makes the API accept small images; it
    // does not add detail, so the returned breed should still be treated as
    // an estimate.
    final scale = minimumSide / shortestSide;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: (width * scale).ceil(),
      targetHeight: (height * scale).ceil(),
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) throw StateError('No se pudo preparar la imagen.');
        return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
