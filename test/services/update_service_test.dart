import 'package:flutter_test/flutter_test.dart';
import 'package:sinotruk_app/services/update_service.dart';

void main() {
  group('UpdateService', () {
    test('isNewer solo con build remoto mayor', () {
      expect(UpdateService.isNewer(currentBuild: 1, remoteBuild: 2), isTrue);
      expect(UpdateService.isNewer(currentBuild: 2, remoteBuild: 2), isFalse);
      expect(UpdateService.isNewer(currentBuild: 3, remoteBuild: 2), isFalse);
    });

    test('AppRelease.fromMap tolera nulos y tipos numéricos', () {
      final r = AppRelease.fromMap({
        'version': '1.1.0',
        'build_number': 2,
        'apk_url': 'https://example.com/app.apk',
      });
      expect(r.version, '1.1.0');
      expect(r.buildNumber, 2);
      expect(r.apkUrl, 'https://example.com/app.apk');
      expect(r.sha256, isNull);
      expect(r.changelog, '');

      final empty = AppRelease.fromMap({});
      expect(empty.version, '');
      expect(empty.buildNumber, 0);
      expect(empty.apkUrl, '');
    });
  });
}
