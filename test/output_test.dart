import 'package:sah/src/output.dart';
import 'package:test/test.dart';

void main() {
  group('SahOutput.flattenDevices', () {
    test('flattens wifi/ethernet map', () {
      final devices = SahOutput.flattenDevices({
        'wifi': [
          {'Name': 'phone', 'Active': true},
        ],
        'ethernet': [
          {'Name': 'ap', 'Active': true},
        ],
      });
      expect(devices.map((d) => d['Name']), ['phone', 'ap']);
    });

    test('passes through list', () {
      final devices = SahOutput.flattenDevices([
        {'Name': 'a'},
        {'Name': 'b'},
      ]);
      expect(devices.length, 2);
    });
  });

  group('SahOutput.bestIpv4', () {
    test('prefers dotted IPAddress', () {
      expect(
        SahOutput.bestIpv4({
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
        SahOutput.bestIpv4({
          'IPAddress': 'fe80::1',
          'IPv4Address': [
            {'Address': '192.168.2.44'},
          ],
        }),
        '192.168.2.44',
      );
    });
  });

  group('SahOutput.formatMbps', () {
    test('SoftAtHome kbps to Mbps', () {
      expect(SahOutput.formatMbps(940123), '940.1');
      expect(SahOutput.formatMbps(1000), '1.0');
    });
  });
}
