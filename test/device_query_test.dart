import 'package:sah/src/device_query.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceQuery', () {
    final device = <String, Object>{
      'Name': 'Example-Laptop',
      'PhysAddress': '02:00:00:00:00:01',
      'IPAddress': '192.168.2.100',
      'Names': [
        {'Name': 'MacBook-Example', 'Source': 'mdns'},
      ],
      'IPv4Address': [
        {'Address': '192.168.2.100', 'Reserved': true},
      ],
    };

    test('matches name substring', () {
      expect(const DeviceQuery('macbook').matches(device), isTrue);
      expect(const DeviceQuery('example').matches(device), isTrue);
      expect(const DeviceQuery('iphone').matches(device), isFalse);
    });

    test('matches mac and ip', () {
      expect(const DeviceQuery('02:00:00').matches(device), isTrue);
      expect(const DeviceQuery('192.168.2.100').matches(device), isTrue);
    });

    test('isReserved', () {
      expect(DeviceQuery.isReserved(device), isTrue);
      expect(DeviceQuery.isReserved({'IPv4Address': []}), isFalse);
    });

    test('looksLikeIpv4', () {
      expect(DeviceQuery.looksLikeIpv4('192.168.2.100'), isTrue);
      expect(DeviceQuery.looksLikeIpv4('192.168.2'), isFalse);
      expect(DeviceQuery.looksLikeIpv4('192.168.2.256'), isFalse);
      expect(DeviceQuery.looksLikeIpv4('macbook'), isFalse);
    });

    test('looksLikeMac and normalizeMac', () {
      expect(DeviceQuery.looksLikeMac('02:00:00:00:00:01'), isTrue);
      expect(DeviceQuery.looksLikeMac('02-00-00-00-00-01'), isTrue);
      expect(DeviceQuery.looksLikeMac('020000000001'), isTrue);
      expect(DeviceQuery.looksLikeMac('02:00:00'), isFalse);
      expect(
        DeviceQuery.normalizeMac('02-00-00-00-00-01'),
        '02:00:00:00:00:01',
      );
      expect(
        DeviceQuery.normalizeMac('020000000001'),
        '02:00:00:00:00:01',
      );
    });

    test('filter prefers exact IPv4 over substring', () {
      final devices = [
        device,
        <String, Object>{
          'Name': 'Other',
          'PhysAddress': '02:00:00:00:00:02',
          'IPAddress': '192.168.2.10',
        },
        <String, Object>{
          'Name': 'Also',
          'PhysAddress': '02:00:00:00:00:03',
          'IPAddress': '192.168.2.100',
        },
      ];
      // Substring '192.168.2.10' would also match '192.168.2.100'.
      final matched = const DeviceQuery('192.168.2.10').filter(devices);
      expect(matched, hasLength(1));
      expect(matched.single['Name'], 'Other');
    });

    test('filter prefers exact MAC', () {
      final devices = [
        device,
        <String, Object>{
          'Name': 'Prefix',
          'PhysAddress': '02:00:00:00:00:11',
          'IPAddress': '192.168.2.11',
        },
      ];
      final matched = const DeviceQuery('02:00:00:00:00:01').filter(devices);
      expect(matched, hasLength(1));
      expect(matched.single['Name'], 'Example-Laptop');
    });
  });
}
