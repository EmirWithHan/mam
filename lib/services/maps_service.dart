import 'package:url_launcher/url_launcher.dart';

class MapsService {
  const MapsService();

  Future<void> openEventLocation({
    double? latitude,
    double? longitude,
    String? locationText,
    String? city,
    String? district,
    String? label,
  }) async {
    final hasCoordinates = latitude != null && longitude != null;
    final cleanLocationText = locationText?.trim();

    if (!hasCoordinates &&
        (cleanLocationText == null || cleanLocationText.isEmpty)) {
      throw StateError('Konum bilgisi bulunamadı.');
    }

    final urls = eventLocationCandidates(
      latitude: latitude,
      longitude: longitude,
      locationText: cleanLocationText,
      city: city,
      district: district,
      label: label,
    );

    for (final url in urls) {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
    }

    throw StateError('Harita uygulaması açılamadı.');
  }

  List<Uri> eventLocationCandidates({
    double? latitude,
    double? longitude,
    String? locationText,
    String? city,
    String? district,
    String? label,
  }) {
    final hasCoordinates = latitude != null && longitude != null;
    final cleanLocationText = locationText?.trim();

    if (hasCoordinates) {
      return [
        _geoCoordinatesUrl(
          latitude: latitude,
          longitude: longitude,
          label: label ?? cleanLocationText,
        ),
        _appleMapsCoordinatesUrl(latitude, longitude, label),
        _openStreetMapCoordinatesUrl(latitude, longitude),
      ];
    }

    if (cleanLocationText == null || cleanLocationText.isEmpty) {
      return const [];
    }

    final searchQuery = contextualSearchQuery(
      locationText: cleanLocationText,
      city: city,
      district: district,
    );

    return [
      _geoSearchUrl(searchQuery),
      _appleMapsSearchUrl(searchQuery),
      _openStreetMapSearchUrl(searchQuery),
    ];
  }

  String contextualSearchQuery({
    required String locationText,
    String? city,
    String? district,
  }) {
    final parts = <String>[];
    final cleanLocationText = locationText.trim();
    if (cleanLocationText.isNotEmpty) parts.add(cleanLocationText);
    _addIfMissing(parts, district);
    _addIfMissing(parts, city);
    _addIfMissing(parts, 'Türkiye');
    return parts.join(', ');
  }

  void _addIfMissing(List<String> parts, String? value) {
    final cleanValue = value?.trim();
    if (cleanValue == null || cleanValue.isEmpty) return;

    final normalizedValue = _normalizeForComparison(cleanValue);
    final alreadyIncluded = parts.any(
      (part) => _normalizeForComparison(part).contains(normalizedValue),
    );
    if (!alreadyIncluded) parts.add(cleanValue);
  }

  String _normalizeForComparison(String value) {
    return value.trim().toLowerCase().replaceAll('ı', 'i').replaceAll('İ', 'i');
  }

  Uri _geoCoordinatesUrl({
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

  Uri _geoSearchUrl(String locationText) {
    return Uri(
      scheme: 'geo',
      path: '0,0',
      queryParameters: {'q': locationText},
    );
  }

  Uri _appleMapsCoordinatesUrl(
    double latitude,
    double longitude,
    String? label,
  ) {
    final query =
        '${latitude.toStringAsFixed(6)},'
        '${longitude.toStringAsFixed(6)}';
    final cleanLabel = label?.trim();
    return Uri.https('maps.apple.com', '/', {
      'll': query,
      if (cleanLabel != null && cleanLabel.isNotEmpty) 'q': cleanLabel,
    });
  }

  Uri _appleMapsSearchUrl(String locationText) {
    return Uri.https('maps.apple.com', '/', {'q': locationText});
  }

  Uri _openStreetMapCoordinatesUrl(double latitude, double longitude) {
    return Uri.https('www.openstreetmap.org', '/', {
      'mlat': latitude.toStringAsFixed(6),
      'mlon': longitude.toStringAsFixed(6),
      'zoom': '16',
    });
  }

  Uri _openStreetMapSearchUrl(String locationText) {
    return Uri.https('www.openstreetmap.org', '/search', {
      'query': locationText,
    });
  }
}
