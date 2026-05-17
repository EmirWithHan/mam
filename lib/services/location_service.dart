import 'package:geocoding/geocoding.dart';
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

  Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet()
          .toList();

      if (parts.isEmpty) return null;
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  String formatCoordinates(double latitude, double longitude) {
    return 'Konum seçildi: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}
