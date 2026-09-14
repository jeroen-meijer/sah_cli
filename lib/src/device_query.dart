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

  /// Prefer exact IPv4 / MAC matches when [query] looks like one; else substring.
  List<Map<String, dynamic>> filter(Iterable<Map<String, dynamic>> devices) {
    final q = query.trim();
    if (q.isEmpty) {
      return [for (final d in devices) d];
    }
    if (looksLikeIpv4(q)) {
      final exact = [
        for (final d in devices)
          if (SahOutput.bestIpv4(d) == q) d,
      ];
      if (exact.isNotEmpty) {
        return exact;
      }
    }
    if (looksLikeMac(q)) {
      final want = normalizeMac(q);
      final exact = [
        for (final d in devices)
          if (normalizeMac(macOf(d)) == want) d,
      ];
      if (exact.isNotEmpty) {
        return exact;
      }
    }
    return [for (final d in devices) if (matches(d)) d];
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

  /// Lowercase colon-separated MAC; strips common separators.
  static String normalizeMac(String mac) {
    final hex = mac.replaceAll(RegExp('[^0-9A-Fa-f]'), '').toLowerCase();
    if (hex.length != 12) {
      return mac.trim().toLowerCase().replaceAll('-', ':');
    }
    final parts = <String>[
      for (var i = 0; i < 12; i += 2) hex.substring(i, i + 2),
    ];
    return parts.join(':');
  }

  /// Dotted decimal IPv4 (four 0–255 octets).
  static bool looksLikeIpv4(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255 || part != '$n') {
        return false;
      }
    }
    return true;
  }

  /// Full MAC with `:` / `-` / no separators (12 hex digits).
  static bool looksLikeMac(String value) {
    final hex = value.replaceAll(RegExp('[^0-9A-Fa-f]'), '');
    return hex.length == 12;
  }
}
