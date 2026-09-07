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

/// SoftAtHome `Active == true` (hosts, leases, topology nodes).
bool hostIsActive(Map<String, dynamic> row) => row['Active'] == true;

/// Rows with [hostIsActive].
List<Map<String, dynamic>> whereActive(
  Iterable<Map<String, dynamic>> rows,
) => [for (final row in rows) if (hostIsActive(row)) row];

/// Prune topology nodes with `Active == false` (and their subtrees).
///
/// Nodes without an `Active` field are kept. Children lists are rewritten
/// with only surviving descendants.
Object? filterActiveTopology(Object? status) {
  if (status is List) {
    return [
      for (final item in status)
        if (_asRow(item) case final node?) ?filterActiveTopologyNode(node),
    ];
  }
  final root = _asRow(status);
  if (root == null) {
    return status;
  }
  return filterActiveTopologyNode(root);
}

/// Single topology node filter; returns `null` when the node is inactive.
Map<String, dynamic>? filterActiveTopologyNode(Map<String, dynamic> node) {
  if (node['Active'] == false) {
    return null;
  }
  final children = node['Children'];
  if (children is! List) {
    return node;
  }
  final pruned = <Map<String, dynamic>>[
    for (final child in children)
      if (_asRow(child) case final map?) ?filterActiveTopologyNode(map),
  ];
  return {...node, 'Children': pruned};
}

Map<String, dynamic>? _asRow(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}
