class MapboxConfig {
  static const mapboxAccessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';
  static const openStreetMapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static bool get isConfigured =>
      mapboxAccessToken.trim().isNotEmpty &&
      mapboxAccessToken.trim() != 'YOUR_MAPBOX_ACCESS_TOKEN';

  static String buildStyleUrl() {
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}?access_token=$mapboxAccessToken';
  }

  static String get tileUrl =>
      isConfigured ? buildStyleUrl() : openStreetMapTileUrl;

  static String get providerLabel =>
      isConfigured ? 'Mapbox streets' : 'OpenStreetMap preview';

  static const mapboxStyleUrl =
      'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}?access_token=YOUR_MAPBOX_ACCESS_TOKEN';
}
