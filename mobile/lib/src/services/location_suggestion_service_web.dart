// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class LocationSuggestion {
  const LocationSuggestion({
    this.country = '',
    this.region = '',
    this.city = '',
    this.source = '',
  });

  final String country;
  final String region;
  final String city;
  final String source;

  bool get hasLocation =>
      country.trim().isNotEmpty ||
      region.trim().isNotEmpty ||
      city.trim().isNotEmpty;
}

class LocationSuggestionService {
  const LocationSuggestionService();

  Future<LocationSuggestion> detectApproximate() async {
    try {
      final position = await html.window.navigator.geolocation
          .getCurrentPosition(
            enableHighAccuracy: false,
            timeout: const Duration(seconds: 8),
            maximumAge: const Duration(minutes: 20),
          );
      final coords = position.coords;
      final suggestion = _fromCoordinates(coords?.latitude, coords?.longitude);
      if (suggestion.hasLocation) return suggestion;
    } catch (_) {
      // Permission denial, unavailable browser support, or timeout keeps the
      // profile location empty so the user can complete it manually.
    }
    return const LocationSuggestion();
  }
}

LocationSuggestion _fromCoordinates(num? latitude, num? longitude) {
  if (latitude == null || longitude == null) return const LocationSuggestion();
  final lat = latitude.toDouble();
  final lon = longitude.toDouble();

  if (_inside(lat, lon, -56, -21, -74, -53)) {
    return const LocationSuggestion(
      country: 'Argentina',
      region: 'Argentina',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -56, -17, -76, -66)) {
    return const LocationSuggestion(
      country: 'Chile',
      region: 'Chile',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -35, -30, -58.8, -53)) {
    return const LocationSuggestion(
      country: 'Uruguay',
      region: 'Uruguay',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -28, -19, -63, -54)) {
    return const LocationSuggestion(
      country: 'Paraguay',
      region: 'Paraguay',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -34, 6, -82, -68)) {
    return const LocationSuggestion(
      country: 'Perú',
      region: 'Perú',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -23, 6, -70, -57)) {
    return const LocationSuggestion(
      country: 'Bolivia',
      region: 'Bolivia',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -34, 6, -74, -34)) {
    return const LocationSuggestion(
      country: 'Brasil',
      region: 'Brasil',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -5, 13, -82, -66)) {
    return const LocationSuggestion(
      country: 'Colombia',
      region: 'Colombia',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, -6, 2, -82, -75)) {
    return const LocationSuggestion(
      country: 'Ecuador',
      region: 'Ecuador',
      source: 'ubicación aproximada',
    );
  }
  if (_inside(lat, lon, 14, 33, -119, -86)) {
    return const LocationSuggestion(
      country: 'México',
      region: 'México',
      source: 'ubicación aproximada',
    );
  }
  return const LocationSuggestion();
}

bool _inside(
  double lat,
  double lon,
  double minLat,
  double maxLat,
  double minLon,
  double maxLon,
) {
  return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
}
