import 'package:url_launcher/url_launcher.dart';

class MapsService {
  const MapsService();

  Future<void> openEventLocation({
    double? latitude,
    double? longitude,
    String? locationText,
    String? label,
  }) async {
    final hasCoordinates = latitude != null && longitude != null;
    final cleanLocationText = locationText?.trim();

    if (!hasCoordinates &&
        (cleanLocationText == null || cleanLocationText.isEmpty)) {
      throw StateError('Konum bilgisi bulunamadı.');
    }

    final fallbackUrl = hasCoordinates
        ? _googleMapsCoordinatesUrl(latitude, longitude)
        : _googleMapsSearchUrl(cleanLocationText!);

    if (hasCoordinates) {
      final nativeUrl = _geoUrl(
        latitude: latitude,
        longitude: longitude,
        label: label ?? cleanLocationText,
      );
      if (await canLaunchUrl(nativeUrl)) {
        final launched = await launchUrl(
          nativeUrl,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    }

    if (await canLaunchUrl(fallbackUrl)) {
      final launched = await launchUrl(
        fallbackUrl,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    }

    throw StateError('Harita uygulaması açılamadı.');
  }

  Uri _geoUrl({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final coordinates =
        '${latitude.toStringAsFixed(6)},'
        '${longitude.toStringAsFixed(6)}';
    final cleanLabel = label?.trim();
    final query = cleanLabel == null || cleanLabel.isEmpty
        ? coordinates
        : '$coordinates($cleanLabel)';

    return Uri(scheme: 'geo', path: coordinates, queryParameters: {'q': query});
  }

  Uri _googleMapsCoordinatesUrl(double latitude, double longitude) {
    final query =
        '${latitude.toStringAsFixed(6)},'
        '${longitude.toStringAsFixed(6)}';
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  Uri _googleMapsSearchUrl(String locationText) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': locationText,
    });
  }
}
