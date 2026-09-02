// Field helpers for SoftAtHome `Devices.get` host rows.

/// SoftAtHome ISO timestamp → local `YYYY-MM-DD HH:MM`.
/// Empty for missing or sentinel `0001-01-01…` values.
String formatSahTime(Object? raw) {
  final text = raw?.toString() ?? '';
  if (text.isEmpty || text.startsWith('0001-01-01')) {
    return '';
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return text;
  }
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Prefer dotted IPv4 from `IPAddress`, else first `IPv4Address[].Address`.
String hostBestIpv4(Map<String, dynamic> device) {
  final ip = device['IPAddress']?.toString() ?? '';
  if (ip.contains('.') && !ip.contains(':')) {
    return ip;
  }
  final list = device['IPv4Address'];
  if (list is List) {
    for (final entry in list) {
      if (entry is Map && entry['Address'] is String) {
        return entry['Address'] as String;
      }
    }
  }
  return ip;
}

/// True when any `IPv4Address` entry has `Reserved: true`.
bool hostReserved(Map<String, dynamic> device) {
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
