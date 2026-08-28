import 'package:sah/src/api/sah_client.dart';
import 'package:test/test.dart';

void main() {
  group('SahClient cookie parsing', () {
    test('prefers sessid cookie', () {
      final cookie = SahClient.firstSetCookieForTest({
        'set-cookie': 'a1b2c3d4/accept-language=en; Path=/, a1b2c3d4/sessid=abc123; Path=/',
      });
      expect(cookie, 'a1b2c3d4/sessid=abc123');
    });

    test('falls back to first pair', () {
      final cookie = SahClient.firstSetCookieForTest({
        'set-cookie': 'only=one; Path=/',
      });
      expect(cookie, 'only=one');
    });
  });
}
