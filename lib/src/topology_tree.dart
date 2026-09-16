import 'package:sah/src/host_row.dart';
import 'package:sah/src/style.dart';

/// One printed row of a SoftAtHome topology tree.
class const TopologyLine(
  final String branchPrefix,
  final Map<String, dynamic> node,
) {
  /// True when the node has a MAC and a current IPv4 (can lock DHCP).
  bool get selectable {
    final mac = node['PhysAddress']?.toString() ?? '';
    return mac.isNotEmpty && hostBestIpv4(node).isNotEmpty;
  }
}

/// Flatten SoftAtHome topology status into display rows (depth-first).
List<TopologyLine> flattenTopology(Object? status) {
  final roots = <Map<String, dynamic>>[];
  if (status is List) {
    for (final item in status) {
      final map = _asMap(item);
      if (map != null) {
        roots.add(map);
      }
    }
  } else {
    final map = _asMap(status);
    if (map != null) {
      roots.add(map);
    }
  }

  final out = <TopologyLine>[];
  for (final root in roots) {
    _walk(root, '', '', out);
  }
  return out;
}

void _walk(
  Map<String, dynamic> node,
  String prefix,
  String childPrefix,
  List<TopologyLine> out,
) {
  out.add(TopologyLine(prefix, node));
  final children = node['Children'];
  if (children is! List || children.isEmpty) {
    return;
  }
  for (var i = 0; i < children.length; i++) {
    final child = _asMap(children[i]);
    if (child == null) {
      continue;
    }
    final last = i == children.length - 1;
    final branch = last ? '└─ ' : '├─ ';
    final nextChild = last ? '   ' : '│  ';
    _walk(child, '$childPrefix$branch', '$childPrefix$nextChild', out);
  }
}

/// Same label bits as `sah topology` (active dot, name, ssid, ip, mac).
///
/// When [emphasize] is true, the whole label is bold cyan (picker focus);
/// nested per-field colors are skipped so the highlight reads clearly.
String topologyLabel(
  Map<String, dynamic> node,
  SahStyle style, {
  bool emphasize = false,
}) {
  final name = node['Name']?.toString() ?? node['Key']?.toString() ?? '?';
  final bits = <String>[];
  final active = node['Active'];
  if (active == true) {
    bits.add(SahStyle.activeFilled);
  } else if (active == false) {
    bits.add(SahStyle.activeEmpty);
  }
  bits.add(name);
  final ssid = node['SSID']?.toString();
  if (ssid != null && ssid.isNotEmpty) {
    bits.add('ssid=$ssid');
  }
  final ip = hostBestIpv4(node);
  if (ip.isNotEmpty) {
    bits.add(ip);
  }
  final mac = node['PhysAddress']?.toString();
  if (mac != null && mac.isNotEmpty && mac != name) {
    bits.add(mac);
  }
  final plain = bits.join('  ');
  if (emphasize) {
    return style.selected(plain);
  }
  // Colored path for normal topology / unfocused picker rows.
  final colored = <String>[];
  final dot = style.activeDot(active);
  if (dot.isNotEmpty) {
    colored.add(dot);
  }
  colored.add(style.name(name));
  if (ssid != null && ssid.isNotEmpty) {
    colored.add(style.ssid('ssid=$ssid'));
  }
  if (ip.isNotEmpty) {
    colored.add(style.ip(ip));
  }
  if (mac != null && mac.isNotEmpty && mac != name) {
    colored.add(style.mac(mac));
  }
  return colored.join('  ');
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}
