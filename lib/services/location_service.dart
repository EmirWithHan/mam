import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService();

  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Konum servisleri kapalı. Lütfen konumu açıp tekrar dene.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError('Konum izni verilmedi.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verebilirsin.',
      );
    }

    return Geolocator.getCurrentPosition();
  }
}
