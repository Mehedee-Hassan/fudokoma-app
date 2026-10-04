import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follo_cart/config/api_config.dart';

void main() {
  test('uses the deployed HTTPS API on Android by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(
      ApiConfig.baseUrl,
      'https://srv1518746.hstgr.cloud',
    );
  });
}
