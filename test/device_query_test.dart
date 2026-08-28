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
  });
}
