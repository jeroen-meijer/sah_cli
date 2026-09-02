import 'package:sah/src/host_row.dart';
import 'package:sah/src/table.dart';

/// Default column catalogs for tabular SoftAtHome commands.
///
/// [SahTableColumn.id] is the table header and `--fields` / `--sort-by` name.
/// Higher [SahTableColumn.priority] = truncated / dropped first when narrow.
abstract final class SahTableSchemas() {
  /// `sah devices` / `sah find`.
  static final devices = <SahTableColumn>[
    SahTableColumn(
      id: 'Active',
      value: (row) => row['Active'],
      format: (v, s) => s.yesNo(v),
      priority: 40,
      flexible: false,
    ),
    SahTableColumn(
      id: 'Reserved',
      value: hostReserved,
      format: (v, s) => s.reserved(v),
      priority: 30,
      flexible: false,
    ),
    SahTableColumn(
      id: 'Name',
      value: (row) => row['Name']?.toString() ?? '',
      format: (v, s) => s.name('$v'),
      priority: 0,
    ),
    SahTableColumn(
      id: 'IP',
      value: hostBestIpv4,
      format: (v, s) => s.ip('$v'),
      priority: 10,
      flexible: false,
    ),
    SahTableColumn(
      id: 'MAC',
      value: (row) => '${row['PhysAddress'] ?? row['Key'] ?? ''}',
      format: (v, s) => s.mac('$v'),
      priority: 20,
    ),
    SahTableColumn(
      id: 'Type',
      value: (row) => row['DeviceType']?.toString() ?? '',
      format: (v, s) => s.muted('$v'),
      priority: 60,
    ),
    SahTableColumn(
      id: 'Interface',
      value: (row) =>
          '${row['InterfaceName'] ?? row['Layer2Interface'] ?? ''}',
      format: (v, s) => s.muted('$v'),
      priority: 70,
    ),
    SahTableColumn(
      id: 'FirstSeen',
      value: (row) => row['FirstSeen'],
      format: (v, s) => s.muted(formatSahTime(v)),
      priority: 80,
    ),
    SahTableColumn(
      id: 'LastConnection',
      value: (row) => row['LastConnection'],
      format: (v, s) => s.muted(formatSahTime(v)),
      priority: 90,
    ),
  ];

  /// `sah dhcp leases` / `sah dhcp static`.
  static final dhcpLeases = <SahTableColumn>[
    SahTableColumn(
      id: 'MAC',
      value: (row) => '${row['MACAddress'] ?? row['Chaddr'] ?? ''}',
      format: (v, s) => s.mac('$v'),
      priority: 20,
    ),
    SahTableColumn(
      id: 'IP',
      value: (row) => '${row['IPAddress'] ?? row['Yiaddr'] ?? ''}',
      format: (v, s) => s.ip('$v'),
      priority: 10,
      flexible: false,
    ),
    SahTableColumn(
      id: 'Name',
      value: (row) => '${row['FriendlyName'] ?? row['Alias'] ?? ''}',
      format: (v, s) => s.name('$v'),
      priority: 0,
    ),
    SahTableColumn(
      id: 'Active',
      value: (row) => row['Active'],
      format: (v, s) => s.yesNo(v),
      priority: 40,
      flexible: false,
    ),
    SahTableColumn(
      id: 'Reserved',
      value: (row) => row['Reserved'],
      format: (v, s) => s.reserved(v),
      priority: 30,
      flexible: false,
    ),
    SahTableColumn(
      id: 'LeaseRemaining',
      value: (row) => row['LeaseTimeRemaining'],
      format: (v, s) => s.muted('${v ?? ''}'),
      priority: 80,
    ),
  ];

  /// `sah ports`.
  static final portForwards = <SahTableColumn>[
    SahTableColumn(
      id: 'Enable',
      value: (row) => row['Enable'],
      format: (v, s) => s.yesNo(v),
      priority: 40,
      flexible: false,
    ),
    SahTableColumn(
      id: 'Name',
      value: (row) =>
          '${row['Description'] ?? row['Id'] ?? row['Name'] ?? ''}',
      format: (v, s) => s.name('$v'),
      priority: 0,
    ),
    SahTableColumn(
      id: 'Protocol',
      value: (row) => row['Protocol']?.toString() ?? '',
      format: (v, s) => s.muted('$v'),
      flexible: false,
    ),
    SahTableColumn(
      id: 'ExtPort',
      value: (row) =>
          '${row['ExternalPort'] ?? row['ExternalPortEndRange'] ?? ''}',
      priority: 20,
      flexible: false,
    ),
    SahTableColumn(
      id: 'DestIP',
      value: (row) {
        final ip = row['DestinationIPAddress'] ?? row['DestinationMACAddress'];
        return '${ip ?? ''}';
      },
      format: (v, s) => s.ip('$v'),
      priority: 10,
      flexible: false,
    ),
    SahTableColumn(
      id: 'DestPort',
      value: (row) => '${row['InternalPort'] ?? row['DestinationPort'] ?? ''}',
      priority: 30,
      flexible: false,
    ),
  ];
}
