import 'package:flutter/foundation.dart';

class ApiConfig {
  static const androidTestBaseUrl = 'https://srv1518746.hstgr.cloud';
  static const _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidTestBaseUrl;
    }
    return 'http://localhost:18000';
  }
}
