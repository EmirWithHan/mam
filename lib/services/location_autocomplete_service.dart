import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;

class LocationSuggestion {
  final String description;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;

  const LocationSuggestion({
    required this.description,
    required this.city,
    required this.district,
    this.latitude,
    this.longitude,
  });
}

class LocationAutocompleteService {
  const LocationAutocompleteService();

  // Mock locations for popular Turkish sports areas
  static const List<LocationSuggestion> _popularSportsVenues = [
    LocationSuggestion(
      description: 'Atatürk Olimpiyat Stadı, Başakşehir, İstanbul',
      city: 'İstanbul',
      district: 'Başakşehir',
      latitude: 41.0744,
      longitude: 28.7656,
    ),
    LocationSuggestion(
      description: 'Burhan Felek Spor Kompleksi, Üsküdar, İstanbul',
      city: 'İstanbul',
      district: 'Üsküdar',
      latitude: 41.0189,
      longitude: 29.0270,
    ),
    LocationSuggestion(
      description: 'Sinan Erdem Spor Salonu, Bakırköy, İstanbul',
      city: 'İstanbul',
      district: 'Bakırköy',
      latitude: 40.9886,
      longitude: 28.8597,
    ),
    LocationSuggestion(
      description: 'Ülker Spor ve Etkinlik Salonu, Ataşehir, İstanbul',
      city: 'İstanbul',
      district: 'Ataşehir',
      latitude: 40.9922,
      longitude: 29.1009,
    ),
    LocationSuggestion(
      description: 'Vodafone Park (Beşiktaş Stadyumu), Beşiktaş, İstanbul',
      city: 'İstanbul',
      district: 'Beşiktaş',
      latitude: 41.0392,
      longitude: 29.0019,
    ),
    LocationSuggestion(
      description: 'Fenerbahçe Şükrü Saracoğlu Stadyumu, Kadıköy, İstanbul',
      city: 'İstanbul',
      district: 'Kadıköy',
      latitude: 40.9877,
      longitude: 29.0370,
    ),
    LocationSuggestion(
      description: 'Galatasaray Nef Stadyumu, Sarıyer, İstanbul',
      city: 'İstanbul',
      district: 'Sarıyer',
      latitude: 41.1034,
      longitude: 28.9910,
    ),
    LocationSuggestion(
      description: 'Ankara Arena, Altındağ, Ankara',
      city: 'Ankara',
      district: 'Altındağ',
      latitude: 39.9416,
      longitude: 32.8520,
    ),
    LocationSuggestion(
      description: 'Eryaman Stadyumu, Etimesgut, Ankara',
      city: 'Ankara',
      district: 'Etimesgut',
      latitude: 39.9702,
      longitude: 32.6394,
    ),
    LocationSuggestion(
      description:
          'Mustafa Kemal Atatürk Karşıyaka Spor Salonu, Karşıyaka, İzmir',
      city: 'İzmir',
      district: 'Karşıyaka',
      latitude: 38.4842,
      longitude: 27.1082,
    ),
    LocationSuggestion(
      description: 'Gürsel Aksel Stadyumu, Konak, İzmir',
      city: 'İzmir',
      district: 'Konak',
      latitude: 38.3992,
      longitude: 27.1000,
    ),
    LocationSuggestion(
      description: 'Nilüfer Tofaş Spor Salonu, Nilüfer, Bursa',
      city: 'Bursa',
      district: 'Nilüfer',
      latitude: 40.2181,
      longitude: 28.9482,
    ),
    LocationSuggestion(
      description: 'Antalya Spor Salonu, Muratpaşa, Antalya',
      city: 'Antalya',
      district: 'Muratpaşa',
      latitude: 36.8967,
      longitude: 30.6622,
    ),
  ];

  Future<List<LocationSuggestion>> getSuggestions({
    required String query,
    String? city,
    String? district,
    double? userLat,
    double? userLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    // 1. Try OSM Nominatim API (Free Turkish general places autocompletion)
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': cleanQuery,
        'format': 'json',
        'addressdetails': '1',
        'limit': '10',
        'countrycodes': 'tr',
      });
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'MatchAManMobileApp/1.0.0',
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> json = jsonDecode(body);
        final suggestions = <LocationSuggestion>[];
        for (final item in json) {
          final address = item['address'] as Map<String, dynamic>? ?? {};
          final displayName = item['display_name'] as String? ?? '';
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');

          final itemCity =
              address['city']?.toString() ??
              address['province']?.toString() ??
              address['state']?.toString() ??
              '';
          final itemDistrict =
              address['suburb']?.toString() ??
              address['town']?.toString() ??
              address['city_district']?.toString() ??
              address['district']?.toString() ??
              '';

          suggestions.add(
            LocationSuggestion(
              description: displayName,
              city: itemCity,
              district: itemDistrict,
              latitude: lat,
              longitude: lon,
            ),
          );
        }

        // Sort by distance to user coordinates if available
        if (userLat != null && userLng != null) {
          suggestions.sort((a, b) {
            if (a.latitude == null || a.longitude == null) return 1;
            if (b.latitude == null || b.longitude == null) return -1;
            final distA = _distanceSq(
              userLat,
              userLng,
              a.latitude!,
              a.longitude!,
            );
            final distB = _distanceSq(
              userLat,
              userLng,
              b.latitude!,
              b.longitude!,
            );
            return distA.compareTo(distB);
          });
        }

        if (suggestions.isNotEmpty) {
          return suggestions.take(5).toList();
        }
      }
    } catch (e) {
      debugPrint('[LocationAutocomplete] OSM Nominatim search failed: $e');
    }

    // 2. Fallback to Local Search
    final queryLower = cleanQuery.toLowerCase();
    final suggestions = <LocationSuggestion>[];

    // Search popular venues
    for (final venue in _popularSportsVenues) {
      if (venue.description.toLowerCase().contains(queryLower)) {
        suggestions.add(venue);
      }
    }

    // Generate dynamic suggestions based on selected city & district
    final selectedCity = city?.trim();
    final selectedDistrict = district?.trim();
    if (selectedCity != null &&
        selectedCity.isNotEmpty &&
        selectedDistrict != null &&
        selectedDistrict.isNotEmpty) {
      final templates = [
        '$selectedDistrict Halı Sahası, $selectedCity',
        '$selectedDistrict Spor Tesisleri, $selectedCity',
        '$selectedDistrict Tenis Kortları, $selectedCity',
        '$selectedDistrict Basketbol Alanı, $selectedCity',
        '$selectedDistrict Koşu Parkuru, $selectedCity',
        '$selectedDistrict Kapalı Spor Salonu, $selectedCity',
      ];
      for (final temp in templates) {
        if (temp.toLowerCase().contains(queryLower)) {
          suggestions.add(
            LocationSuggestion(
              description: temp,
              city: selectedCity,
              district: selectedDistrict,
            ),
          );
        }
      }
    }

    // Sort local results by distance if possible
    if (userLat != null && userLng != null) {
      suggestions.sort((a, b) {
        if (a.latitude == null || a.longitude == null) return 1;
        if (b.latitude == null || b.longitude == null) return -1;
        final distA = _distanceSq(userLat, userLng, a.latitude!, a.longitude!);
        final distB = _distanceSq(userLat, userLng, b.latitude!, b.longitude!);
        return distA.compareTo(distB);
      });
    }

    return suggestions.take(5).toList();
  }

  double _distanceSq(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat1 - lat2;
    final dLng = lng1 - lng2;
    return dLat * dLat + dLng * dLng;
  }

  Future<LocationDetails?> getDetails(LocationSuggestion suggestion) async {
    if (suggestion.latitude != null && suggestion.longitude != null) {
      return LocationDetails(
        description: suggestion.description,
        latitude: suggestion.latitude!,
        longitude: suggestion.longitude!,
      );
    }

    // Try resolving with existing geocoding package
    try {
      final locations = await geo.locationFromAddress(suggestion.description);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return LocationDetails(
          description: suggestion.description,
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      }
    } catch (e) {
      debugPrint('[LocationAutocomplete] Geocoding resolution failed: $e');
    }

    return null;
  }
}

class LocationDetails {
  final String description;
  final double latitude;
  final double longitude;

  const LocationDetails({
    required this.description,
    required this.latitude,
    required this.longitude,
  });
}
