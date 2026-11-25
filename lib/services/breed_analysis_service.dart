import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/models.dart';

class BreedAnalysisService {
  static final _function = FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('analyzeDogPhoto');

  static Future<List<BreedPrediction>> analyze(Uint8List image) async {
    final response = await _function.call<Map<String, dynamic>>({
      'imageBase64': base64Encode(image),
    });
    final raw = response.data['breeds'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => BreedPrediction.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }
}
