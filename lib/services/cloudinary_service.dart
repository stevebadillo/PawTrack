import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Servicio de carga de imágenes a Cloudinary (REST API sin dependencias nativas).
///
/// Para usar Cloudinary sin backend, se utiliza un "unsigned upload preset".
/// Pasos para obtener o cambiar las credenciales en https://cloudinary.com :
/// 1. Cloud Name: Tu nombre de nube en Cloudinary (Dashboard).
/// 2. Upload Preset: Settings > Upload > Add upload preset > Signing Mode: Unsigned.
class CloudinaryService {
  // Configuración de Cloudinary:
  // Puedes reemplazar estos valores con los de tu cuenta de Cloudinary.
  static String cloudName = 'g3o3qo25';
  static String uploadPreset = 'pawtrack';

  /// URL base de la API REST de Cloudinary
  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Sube una foto a Cloudinary y retorna su URL segura HTTPS pública.
  ///
  /// Si Cloudinary aún no tiene configurado el preset unsigned o hay un error,
  /// lanza una excepción detallada para avisar al usuario.
  static Future<String> uploadImage(
    Uint8List imageBytes, {
    String folder = 'canes',
    void Function(double progress)? onProgress,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('La imagen está vacía.');
    }
    if (imageBytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('La imagen no debe superar los 10 MB.');
    }

    final uri = Uri.parse(_uploadUrl);
    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = folder;

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'pawtrack_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
                'La subida a Cloudinary tardó demasiado tiempo.'),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final secureUrl = jsonResponse['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        }
        final url = jsonResponse['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }
        throw Exception('Cloudinary no devolvió una URL válida.');
      } else {
        String errorMsg = 'Error en Cloudinary (${response.statusCode})';
        try {
          final errJson = jsonDecode(response.body);
          if (errJson['error']?['message'] != null) {
            errorMsg = errJson['error']['message'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }
}

