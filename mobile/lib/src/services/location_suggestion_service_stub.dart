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
    return const LocationSuggestion();
  }
}
