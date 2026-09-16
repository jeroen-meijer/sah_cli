import 'package:sah/src/dhcp_leases.dart';
import 'package:test/test.dart';

void main() {
  group('flattenDhcpLeases', () {
    test('unwraps pool → client-id map from getLeases', () {
      final status = {
        'default': {
          '01:aa:bb:cc:dd:ee:ff': {
            'MACAddress': 'aa:bb:cc:dd:ee:ff',
            'IPAddress': '192.168.2.10',
            'FriendlyName': 'Phone',
            'Active': true,
            'Reserved': false,
            'LeaseTimeRemaining': 3600,
          },
          '01:11:22:33:44:55:66': {
            'MACAddress': '11:22:33:44:55:66',
            'IPAddress': '192.168.2.11',
            'Active': false,
          },
        },
      };

      final rows = flattenDhcpLeases(status);
      expect(rows, hasLength(2));
      expect(rows.map((r) => r['MACAddress']), contains('aa:bb:cc:dd:ee:ff'));
      expect(
        rows.firstWhere((r) => r['FriendlyName'] == 'Phone')['Active'],
        isTrue,
      );
    });

    test('passes through getStaticLeases list', () {
      final status = [
        {
          'MACAddress': 'aa:bb:cc:dd:ee:ff',
          'IPAddress': '192.168.2.10',
          'LeasePath': 'DHCPv4.Server.Pool.default.Rule.default.Lease.01:aa',
        },
      ];
      final rows = flattenDhcpLeases(status);
      expect(rows, hasLength(1));
      expect(rows.single['LeasePath'], contains('Lease'));
    });
  });

  group('enrichStaticDhcpLeases', () {
    test('merges lease and host fields by MAC', () {
      final staticRows = [
        {
          'MACAddress': 'AA:BB:CC:DD:EE:FF',
          'IPAddress': '192.168.2.10',
          'LeasePath': 'path',
        },
        {
          'MACAddress': '11:22:33:44:55:66',
          'IPAddress': '192.168.2.20',
        },
      ];
      final dynamicLeases = [
        {
          'MACAddress': 'aa:bb:cc:dd:ee:ff',
          'FriendlyName': 'FromLease',
          'Active': true,
          'Reserved': true,
          'LeaseTimeRemaining': 120,
        },
      ];
      final hosts = [
        {
          'Name': 'FromHost',
          'PhysAddress': '11:22:33:44:55:66',
          'Active': true,
        },
      ];

      final rows = enrichStaticDhcpLeases(
        staticRows: staticRows,
        dynamicLeases: dynamicLeases,
        hosts: hosts,
      );

      expect(rows[0]['FriendlyName'], 'FromLease');
      expect(rows[0]['Active'], isTrue);
      expect(rows[0]['Reserved'], isTrue);
      expect(rows[0]['LeaseTimeRemaining'], 120);

      expect(rows[1]['FriendlyName'], 'FromHost');
      expect(rows[1]['Active'], isTrue);
      expect(rows[1]['Reserved'], isTrue);
    });
  });

  group('formatLeaseRemaining', () {
    test('formats seconds and expired', () {
      expect(formatLeaseRemaining(null), '');
      expect(formatLeaseRemaining(-1), 'expired');
      expect(formatLeaseRemaining(45), '45s');
      expect(formatLeaseRemaining(125), '2m 5s');
      expect(formatLeaseRemaining(3725), '1h 2m');
    });
  });
}
