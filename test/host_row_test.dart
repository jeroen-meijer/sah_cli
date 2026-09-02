import 'package:sah/src/host_row.dart';
import 'package:test/test.dart';

void main() {
  group('formatSahTime', () {
    test('formats ISO UTC to local YYYY-MM-DD HH:MM', () {
      final formatted = formatSahTime('2026-05-16T11:25:37Z');
      final expected = DateTime.parse('2026-05-16T11:25:37Z').toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(
        formatted,
        '${expected.year}-${two(expected.month)}-${two(expected.day)} '
        '${two(expected.hour)}:${two(expected.minute)}',
      );
    });

    test('empty for sentinel and missing', () {
      expect(formatSahTime('0001-01-01T00:00:00Z'), '');
      expect(formatSahTime(null), '');
      expect(formatSahTime(''), '');
    });
  });

  group('hostBestIpv4', () {
    test('prefers dotted IPAddress', () {
      expect(
        hostBestIpv4({
          'IPAddress': '192.168.2.1',
          'IPv4Address': [
            {'Address': '10.0.0.1'},
          ],
        }),
        '192.168.2.1',
      );
    });

    test('falls back to IPv4Address list', () {
      expect(
        hostBestIpv4({
          'IPAddress': 'fe80::1',
          'IPv4Address': [
            {'Address': '192.168.2.44'},
          ],
        }),
        '192.168.2.44',
      );
    });
  });

  group('hostReserved', () {
    test('reads IPv4Address.Reserved', () {
      expect(hostReserved({'IPv4Address': []}), false);
      expect(
        hostReserved({
          'IPv4Address': [
            {'Address': '1.1.1.1', 'Reserved': true},
          ],
        }),
        true,
      );
    });
  });
}
