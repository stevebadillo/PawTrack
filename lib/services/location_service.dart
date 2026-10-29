import 'package:geolocator/geolocator.dart';

/// Geolocalización del dispositivo (RF10).
class LocationService {
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Activa el GPS del dispositivo';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación denegado';
    }
    return Geolocator.getCurrentPosition();
  }
}
