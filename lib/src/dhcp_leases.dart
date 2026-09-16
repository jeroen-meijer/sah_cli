import 'package:sah/src/device_query.dart';
import 'package:sah/src/host_row.dart';

/// Flatten SoftAtHome DHCP lease payloads to row maps.
///
/// `getLeases` is often:
/// `{ "default": { "01:mac…": {…}, … } }`.
/// `getStaticLeases` is usually a list of
/// `{ MACAddress, IPAddress, LeasePath }`.
List<Map<String, dynamic>> flattenDhcpLeases(Object? status) {
  if (status is List) {
    return [
      for (final item in status)
        if (item is Map<String, dynamic>)
          item
        else if (item is Map)
          Map<String, dynamic>.from(item),
    ];
  }
  if (status is! Map) {
    return const [];
  }

  final out = <Map<String, dynamic>>[];
  for (final value in status.values) {
    if (value is List) {
      out.addAll(flattenDhcpLeases(value));
      continue;
    }
    if (value is! Map) {
      continue;
    }
    final map = value is Map<String, dynamic>
        ? value
        : Map<String, dynamic>.from(value);
    if (_looksLikeLeaseRow(map)) {
      out.add(map);
    } else {
      out.addAll(flattenDhcpLeases(map));
    }
  }
  return out;
}

bool _looksLikeLeaseRow(Map<String, dynamic> map) =>
    map.containsKey('MACAddress') ||
    map.containsKey('IPAddress') ||
    map.containsKey('Chaddr') ||
    map.containsKey('Yiaddr') ||
    map.containsKey('LeasePath');

/// Fill Name / Active / Reserved / LeaseTimeRemaining on static rows.
///
/// `getStaticLeases` only returns MAC + IP (+ LeasePath). Prefer matching
/// dynamic lease fields; fall back to Devices.get for a display name.
List<Map<String, dynamic>> enrichStaticDhcpLeases({
  required List<Map<String, dynamic>> staticRows,
  required List<Map<String, dynamic>> dynamicLeases,
  List<Map<String, dynamic>> hosts = const [],
}) {
  final leaseByMac = <String, Map<String, dynamic>>{};
  for (final lease in dynamicLeases) {
    final mac = DeviceQuery.normalizeMac(
      '${lease['MACAddress'] ?? lease['Chaddr'] ?? ''}',
    );
    if (mac.isNotEmpty) {
      leaseByMac[mac] = lease;
    }
  }

  final hostByMac = <String, Map<String, dynamic>>{};
  for (final host in hosts) {
    final mac = DeviceQuery.normalizeMac(DeviceQuery.macOf(host));
    if (mac.isNotEmpty) {
      hostByMac[mac] = host;
    }
  }

  return [
    for (final row in staticRows) _enrichStaticRow(row, leaseByMac, hostByMac),
  ];
}

Map<String, dynamic> _enrichStaticRow(
  Map<String, dynamic> row,
  Map<String, Map<String, dynamic>> leaseByMac,
  Map<String, Map<String, dynamic>> hostByMac,
) {
  final mac = DeviceQuery.normalizeMac(
    '${row['MACAddress'] ?? row['Chaddr'] ?? ''}',
  );
  final lease = leaseByMac[mac];
  final host = hostByMac[mac];
  final enriched = Map<String, dynamic>.from(row);

  if (lease != null) {
    for (final key in const [
      'FriendlyName',
      'Alias',
      'Active',
      'Reserved',
      'LeaseTimeRemaining',
      'LeaseTime',
    ]) {
      if (enriched[key] == null && lease[key] != null) {
        enriched[key] = lease[key];
      }
    }
  }

  final name = '${enriched['FriendlyName'] ?? enriched['Alias'] ?? ''}';
  if (name.isEmpty && host != null) {
    final hostName = '${host['Name'] ?? ''}'.trim();
    if (hostName.isNotEmpty) {
      enriched['FriendlyName'] = hostName;
    }
  }

  // Static list entry implies a reservation even when no live lease is present.
  enriched['Reserved'] ??= true;

  if (enriched['Active'] == null && host != null) {
    enriched['Active'] = hostIsActive(host);
  }

  return enriched;
}

/// Humanize SoftAtHome lease remaining seconds (may be negative).
String formatLeaseRemaining(Object? raw) {
  if (raw == null) {
    return '';
  }
  if (raw is! num) {
    return '$raw';
  }
  final seconds = raw.round();
  if (seconds < 0) {
    return 'expired';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '${h}h ${m}m';
  }
  if (m > 0) {
    return '${m}m ${s}s';
  }
  return '${s}s';
}
