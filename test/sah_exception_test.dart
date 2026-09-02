import 'package:sah/src/api/sah_exception.dart';
import 'package:test/test.dart';

void main() {
  group('SahException.userMessage', () {
    test('maps not authenticated', () {
      final e = SahException('Not authenticated. Run `sah login` first.');
      expect(e.userMessage, 'not authenticated');
      expect(e.tip, 'run `sah login`');
      expect(e.isAuthFailure, isTrue);
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

    test('Permission denied becomes session expired summary', () {
      final e = SahException(
        'API error for DeviceInfo::get: '
        '[{"error":1,"description":"Permission denied"}]',
        body: {
          'errors': [
            {'error': 1, 'description': 'Permission denied'},
          ],
        },
      );
      expect(e.userMessage, 'session expired or permission denied');
      expect(
        e.tip,
        'run `sah login` (stores a password for auto-relogin)',
      );
      expect(e.isAuthFailure, isTrue);
    });

    test('incorrect password factory', () {
      final e = SahException.incorrectPassword(statusCode: 401);
      expect(e.userMessage, 'incorrect password');
      expect(
        e.tip,
        'check --password or SAH_PASSWORD, then run `sah login`',
      );
      expect(e.isAuthFailure, isTrue);
    });

    test('HTTP 401 message maps to incorrect password', () {
      final e = SahException('HTTP 401', statusCode: 401);
      expect(e.userMessage, 'incorrect password');
    });

    test('bare permission denied has no tip', () {
      final e = SahException('permission denied');
      expect(e.userMessage, 'permission denied');
      expect(e.tip, isNull);
    });
  });

  group('formatCliError', () {
    test('strips Exception prefix', () {
      expect(formatCliError(Exception('network down')), 'network down');
    });
  });
}
