import 'package:sah/src/table.dart';
import 'package:sah/src/table_schemas.dart';
import 'package:test/test.dart';

void main() {
  final columns = SahTableSchemas.devices;

  group('SahTableColumnListExtensions', () {
    test('selectFields keeps default order when null', () {
      expect(columns.selectFields(null), same(columns));
    });

    test('selectFields reorders and filters', () {
      final selected = columns.selectFields(const ['MAC', 'Name']);
      expect(selected.map((c) => c.id), ['MAC', 'Name']);
    });

    test('selectFields rejects unknown and empty', () {
      expect(
        () => columns.selectFields(const []),
        throwsFormatException,
      );
      expect(
        () => columns.selectFields(const ['nope']),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unknown field "nope"'),
          ),
        ),
      );
    });

    test('sortKeys validates ids and descending prefix', () {
      expect(columns.sortKeys(const []), isEmpty);
      final keys = columns.sortKeys(const ['Active', '-FirstSeen']);
      expect(keys.map((k) => k.column.id), ['Active', 'FirstSeen']);
      expect(keys.map((k) => k.descending), [false, true]);
      expect(
        () => columns.sortKeys(const ['firstSeen']),
        throwsFormatException,
      );
      expect(
        () => columns.sortKeys(const ['-']),
        throwsFormatException,
      );
    });
  });

  group('SahTableRowListExtensions', () {
    final rows = [
      {
        'Name': 'b',
        'Active': true,
        'FirstSeen': '2026-05-16T11:25:37Z',
        'PhysAddress': 'AA:BB',
      },
      {
        'Name': 'a',
        'Active': false,
        'FirstSeen': '2026-06-01T00:00:00Z',
        'PhysAddress': 'CC:DD',
      },
      {
        'Name': 'c',
        'Active': false,
        'FirstSeen': '2026-01-01T00:00:00Z',
        'PhysAddress': 'EE:FF',
      },
    ];

    test('sortedByColumns multi-key', () {
      final ordered = rows.sortedByColumns(
        columns.sortKeys(const ['Active', 'Name']),
      );
      expect(ordered.map((r) => r['Name']), ['a', 'c', 'b']);
    });

    test('sortedByColumns descending prefix', () {
      final ordered = rows.sortedByColumns(
        columns.sortKeys(const ['-FirstSeen']),
      );
      expect(ordered.map((r) => r['Name']), ['a', 'b', 'c']);
    });

    test('projectColumns keys by column id', () {
      final projected = rows.projectColumns(
        columns.selectFields(const ['Name', 'MAC']),
      );
      expect(projected, [
        {'Name': 'b', 'MAC': 'AA:BB'},
        {'Name': 'a', 'MAC': 'CC:DD'},
        {'Name': 'c', 'MAC': 'EE:FF'},
      ]);
    });
  });

  group('compareTableValues', () {
    test('nulls last and bool/num order', () {
      expect(compareTableValues(null, 1), 1);
      expect(compareTableValues(1, null), -1);
      expect(compareTableValues(false, true), -1);
      expect(compareTableValues(2, 10), -1);
    });
  });

  group('truncateVisible', () {
    test('leaves short strings alone', () {
      expect(truncateVisible('hello', 10), 'hello');
    });

    test('adds ellipsis', () {
      expect(truncateVisible('hello world', 8), 'hello w…');
    });

    test('preserves ansi when content fits', () {
      expect(truncateVisible('\x1B[36mcyan\x1B[0m', 4), '\x1B[36mcyan\x1B[0m');
    });

    test('strips ansi when truncating', () {
      expect(truncateVisible('\x1B[36mcyantext\x1B[0m', 5), 'cyan…');
    });
  });

  group('fitTableToWidth', () {
    final cols = [
      const SahTableColumn(
        id: 'Name',
        value: _empty,
        priority: 0,
      ),
      const SahTableColumn(
        id: 'IP',
        value: _empty,
        priority: 10,
        flexible: false,
      ),
      const SahTableColumn(
        id: 'Extra',
        value: _empty,
        priority: 80,
      ),
    ];

    test('keeps natural widths when they fit', () {
      final fit = fitTableToWidth(
        columns: cols,
        cellText: const [
          ['abc', '1.2.3.4', 'long-extra-value'],
        ],
        terminalWidth: 80,
      );
      expect(fit.columns.map((c) => c.id), ['Name', 'IP', 'Extra']);
      expect(fit.contentWidths[0], 4); // header Name
      expect(fit.contentWidths[1], 7); // 1.2.3.4
      expect(fit.contentWidths[2], 16); // long-extra-value
    });

    test('shrinks highest-priority flexible column first', () {
      final fit = fitTableToWidth(
        columns: cols,
        cellText: const [
          ['MacBookPro', '192.168.2.100', '2026-08-28 20:21'],
        ],
        terminalWidth: 40,
      );
      expect(fit.columns.map((c) => c.id), ['Name', 'IP', 'Extra']);
      expect(fit.contentWidths[2], lessThan(16));
      expect(fit.contentWidths[1], 13);
    });

    test('drops least-important column when shrink is not enough', () {
      final fit = fitTableToWidth(
        columns: cols,
        cellText: const [
          ['MacBookPro', '192.168.2.100', '2026-08-28 20:21'],
        ],
        terminalWidth: 20,
      );
      expect(fit.columns.map((c) => c.id), isNot(contains('Extra')));
      expect(fit.columns.map((c) => c.id), containsAll(['Name', 'IP']));
    });
  });
}

Object? _empty(Map<String, dynamic> row) => '';
