import 'package:sah/src/api/sah_exception.dart';
import 'package:test/test.dart';

void main() {
  group('SahException.userMessage', () {
    test('passes through plain messages', () {
      final e = SahException('Not authenticated. Run `sah login` first.');
      expect(e.userMessage, 'Not authenticated. Run `sah login` first.');
    });

    test('SpeedTest object-not-found', () {
      final e = SahException(
        'API error for SpeedTest.Diagnostics.Download::runDiagnostics: '
        '{"error":196618,"description":"Object or parameter not found"}',
        body: {'error': 196618},
      );
      expect(e.userMessage, 'SpeedTest API not available on this gateway');
    });

    test('generic object-not-found uses call name', () {
      final e = SahException(
        'API error for Foo.Bar::get: '
        '[{"error":196618,"description":"Object or parameter not found"}]',
      );
      expect(e.userMessage, 'Foo.Bar::get not available on this gateway');
    });

    test('uses API description when present', () {
      final e = SahException(
        'API error for DeviceInfo::get: '
        '[{"error":1,"description":"Permission denied"}]',
      );
      expect(e.userMessage, 'Permission denied');
    });
  });

  group('formatCliError', () {
    test('strips Exception prefix', () {
      expect(formatCliError(Exception('network down')), 'network down');
    });
  });
}
