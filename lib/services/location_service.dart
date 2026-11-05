import 'package:geolocator/geolocator.dart';

// ============================================================================
// SERVICIO DE UBICACIÓN GPS (LocationService)
// Verifica que el GPS esté encendido, solicita permisos al usuario y obtiene
// las coordenadas actuales del dispositivo para adjuntarlas a los reportes.
// ============================================================================
class LocationService {
  static Future<Position> current() async {
    // 1. Verifica si el servicio de ubicación del teléfono está activo
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Activa el GPS del dispositivo';
    }

    // 2. Comprueba y solicita permisos de ubicación a la aplicación
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación denegado';
    }

    // 3. Devuelve la posición GPS actual del usuario
    return Geolocator.getCurrentPosition();
  }
}
