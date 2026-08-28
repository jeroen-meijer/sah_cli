import 'package:sah/src/output.dart';

/// Helpers for matching SoftAtHome `Devices.get` rows.
class const DeviceQuery(final String query) {
  bool matches(Map<String, dynamic> device) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }

    final haystacks = <String>[
      '${device['Name'] ?? ''}',
      '${device['PhysAddress'] ?? ''}',
      '${device['Key'] ?? ''}',
      '${device['DeviceType'] ?? ''}',
      SahOutput.bestIpv4(device),
      for (final name in _names(device)) name,
    ];
    return haystacks.any((h) => h.toLowerCase().contains(q));
  }

  static List<String> _names(Map<String, dynamic> device) {
    final names = device['Names'];
    if (names is! List) {
      return const [];
    }
    return [
      for (final entry in names)
        if (entry is Map && entry['Name'] is String) entry['Name'] as String,
    ];
  }

  static bool isReserved(Map<String, dynamic> device) {
    final list = device['IPv4Address'];
    if (list is List) {
      for (final entry in list) {
        if (entry is Map && entry['Reserved'] == true) {
          return true;
        }
      }
    }
    return false;
  }

  static String macOf(Map<String, dynamic> device) =>
      '${device['PhysAddress'] ?? device['Key'] ?? ''}';
}
