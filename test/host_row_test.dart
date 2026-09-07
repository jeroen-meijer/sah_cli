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

  group('whereActive', () {
    test('keeps only Active==true', () {
      final rows = whereActive([
        {'Name': 'a', 'Active': true},
        {'Name': 'b', 'Active': false},
        {'Name': 'c'},
      ]);
      expect(rows.map((r) => r['Name']), ['a']);
    });
  });

  group('filterActiveTopology', () {
    test('prunes inactive leaves and keeps active branch', () {
      final pruned = filterActiveTopology({
        'Name': 'lan',
        'Active': true,
        'Children': [
          {
            'Name': 'wifi',
            'Active': true,
            'Children': [
              {'Name': 'phone', 'Active': true},
              {'Name': 'kobo', 'Active': false},
            ],
          },
          {
            'Name': 'dead-leaf',
            'Active': false,
            'Children': <Map<String, dynamic>>[],
          },
        ],
      })!;

      expect(pruned, isA<Map<String, dynamic>>());
      final root = pruned as Map<String, dynamic>;
      final wifi = (root['Children'] as List).single as Map<String, dynamic>;
      expect(wifi['Name'], 'wifi');
      final kids = wifi['Children']! as List;
      expect(kids.length, 1);
      expect((kids.single as Map)['Name'], 'phone');
    });

    test('keeps inactive parent when a child is active', () {
      final pruned = filterActiveTopology({
        'Name': 'lan',
        'Active': true,
        'Children': [
          {
            'Name': 'tpver',
            'Active': false,
            'Children': [
              {'Name': 'homeplug', 'Active': true},
              {'Name': 'ghost', 'Active': false},
            ],
          },
        ],
      })! as Map<String, dynamic>;

      final tpver = (pruned['Children'] as List).single as Map<String, dynamic>;
      expect(tpver['Name'], 'tpver');
      expect(tpver['Active'], false);
      final kids = tpver['Children']! as List;
      expect(kids.length, 1);
      expect((kids.single as Map)['Name'], 'homeplug');
    });

    test('filters list roots', () {
      final pruned = filterActiveTopology([
        {'Name': 'up', 'Active': true},
        {'Name': 'down', 'Active': false},
      ])! as List;
      expect(
        pruned.map((n) => (n as Map)['Name']),
        ['up'],
      );
    });
  });
}
