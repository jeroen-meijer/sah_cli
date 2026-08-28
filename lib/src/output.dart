import 'dart:convert';
import 'dart:io';

import 'package:cli_table/cli_table.dart';
import 'package:sah/src/config.dart';
import 'package:sah/src/style.dart';

/// Shared stdout helpers: `--json` vs human-readable tables / lists.
class SahOutput(final SahConfig config, {SahStyle? style}) {
  final SahStyle style = style ?? SahStyle();

  /// Compact, borderless table chars (space-separated columns only).
  static const _chars = TableChars(
    top: '',
    topMid: '',
    topLeft: '',
    topRight: '',
    bottom: '',
    bottomMid: '',
    bottomLeft: '',
    bottomRight: '',
    left: '',
    leftMid: '',
    mid: '',
    midMid: '',
    right: '',
    rightMid: '',
    middle: '  ',
  );

  TableStyle get _tableStyle => TableStyle(
    border: const <String>[],
    header: style.enabled ? const ['cyan', 'bold'] : const <String>[],
    compact: true,
    paddingLeft: 0,
    paddingRight: 1,
  );

  void json(Object? data) {
    final encoder = config.jsonOutput
        ? const JsonEncoder()
        : const JsonEncoder.withIndent('  ');
    stdout.writeln(encoder.convert(data));
  }

  /// Emit [data] as JSON when `--json`, otherwise run [pretty].
  void emit(Object? data, void Function() pretty) {
    if (config.jsonOutput) {
      json(data);
    } else {
      pretty();
    }
  }

  void keyValues(Map<String, Object?> fields, {String? title}) {
    if (title != null) {
      stdout.writeln(style.title(title));
    }
    if (fields.isEmpty) {
      stdout.writeln(style.muted('(empty)'));
      return;
    }
    final table = Table(style: _tableStyle, tableChars: _chars);
    for (final entry in fields.entries) {
      table.add({
        style.key(entry.key): style.fieldValue(entry.key, entry.value),
      });
    }
    stdout.writeln(table);
  }

  void rows(List<String> headers, List<List<Object?>> body, {String? title}) {
    if (title != null) {
      stdout.writeln(style.title(title));
    }
    if (body.isEmpty) {
      stdout.writeln(style.muted('(no rows)'));
      return;
    }
    final table = Table(
      header: headers,
      style: _tableStyle,
      tableChars: _chars,
    );
    for (final row in body) {
      table.add(row.map(_cell).toList());
    }
    stdout.writeln(table);
  }

  void deviceInfo(Object? status) {
    final map = _asMap(status);
    if (map == null) {
      json(status);
      return;
    }
    const preferred = [
      'ProductClass',
      'SerialNumber',
      'SoftwareVersion',
      'AdditionalSoftwareVersion',
      'BaseMAC',
      'HardwareVersion',
      'Manufacturer',
      'ModelName',
      'Description',
    ];
    final fields = <String, Object?>{
      for (final key in preferred)
        if (map.containsKey(key)) key: map[key],
    };
    for (final e in map.entries) {
      fields.putIfAbsent(e.key, () => e.value);
    }
    keyValues(fields);
  }

  void wanStatus(Map<String, dynamic> result) {
    final map =
        _asMap(result['data']) ?? _asMap(result['status']) ?? _asMap(result);
    if (map == null) {
      json(result);
      return;
    }
    const preferred = [
      'ConnectionState',
      'LinkType',
      'LinkState',
      'Protocol',
      'IPAddress',
      'IPv6Address',
      'IPv6DelegatedPrefix',
      'RemoteGateway',
      'DNSServers',
      'MACAddress',
      'LastConnectionError',
    ];
    keyValues({
      for (final key in preferred)
        if (map.containsKey(key)) key: map[key],
    });
  }

  /// Print a SoftAtHome / local speed-test result map.
  ///
  /// SoftAtHome `throughput` is kbps (UI divides by 1000 for Mbps).
  /// `duration` is ms; `rxbytes` is bytes.
  void speedTest(Map<String, Object?> payload) {
    final mode = payload['mode']?.toString();
    if (mode != null) {
      final label = switch (mode) {
        'gateway' => 'Gateway',
        'local' => 'Cloudflare on this machine',
        'local-fallback' =>
          'No gateway SpeedTest API; Cloudflare on this machine',
        _ => mode,
      };
      stdout.writeln(style.muted(label));
    }

    final ping = _asMap(payload['ping']);
    if (ping != null) {
      final state = ping['DiagnosticsState']?.toString();
      keyValues({
        'State': ?state,
        if (ping.containsKey('averageResponseTime'))
          'Latency': '${ping['averageResponseTime']} ms',
        if (ping.containsKey('minimumResponseTime'))
          'Min': '${ping['minimumResponseTime']} ms',
        if (ping.containsKey('maximumResponseTime'))
          'Max': '${ping['maximumResponseTime']} ms',
        if (ping.containsKey('packetsSuccess'))
          'Success': ping['packetsSuccess'],
        if (ping.containsKey('packetsFailed')) 'Failure': ping['packetsFailed'],
        if (ping.containsKey('source')) 'Source': ping['source'],
      }, title: 'Ping');
    }

    for (final direction in const ['download', 'upload']) {
      final map = _asMap(payload[direction]);
      if (map == null) {
        continue;
      }
      final fields = <String, Object?>{};
      final throughput = map['throughput'];
      if (throughput is num) {
        fields['Speed'] = '${formatMbps(throughput)} Mbps';
      }
      final rxbytes = map['rxbytes'];
      if (rxbytes is num) {
        fields['Data'] = '${(rxbytes / 1e6).toStringAsFixed(1)} MB';
      }
      final duration = map['duration'];
      if (duration is num) {
        fields['Duration'] = '${(duration / 1000).toStringAsFixed(1)} s';
      }
      if (map['latency'] != null) {
        fields['Latency'] = map['latency'];
      }
      if (map['suite'] != null) {
        fields['Suite'] = map['suite'];
      }
      if (map['testserver'] != null) {
        fields['Server'] = map['testserver'];
      }
      if (map['source'] != null) {
        fields['Source'] = map['source'];
      }
      if (map['RetrievedStartTS'] != null) {
        fields['Started'] = map['RetrievedStartTS'];
      }
      if (map['RetrievedTS'] != null) {
        fields['Finished'] = map['RetrievedTS'];
      }
      keyValues(fields, title: direction == 'download' ? 'Download' : 'Upload');
    }

    final errors = _asMap(payload['errors']);
    if (errors != null && errors.isNotEmpty) {
      keyValues({
        for (final e in errors.entries) e.key: e.value,
      }, title: 'Errors');
    }

    if (!payload.containsKey('ping') &&
        !payload.containsKey('download') &&
        !payload.containsKey('upload')) {
      stdout.writeln(style.muted('(no speed-test results)'));
    }
  }

  /// SoftAtHome kbps → Mbps string with one decimal place.
  static String formatMbps(num throughputKbps) =>
      (throughputKbps / 1000).toStringAsFixed(1);

  void devices(Object? status) {
    final list = flattenDevices(status);
    rows(
      const ['Active', 'Reserved', 'Name', 'IP', 'MAC', 'Type', 'Interface'],
      [
        for (final d in list)
          [
            style.yesNo(d['Active']),
            style.reserved(_deviceReserved(d)),
            style.name('${d['Name'] ?? ''}'),
            style.ip(bestIpv4(d)),
            style.mac('${d['PhysAddress'] ?? d['Key'] ?? ''}'),
            style.muted('${d['DeviceType'] ?? ''}'),
            style.muted('${d['InterfaceName'] ?? d['Layer2Interface'] ?? ''}'),
          ],
      ],
      title: list.isEmpty ? null : '${list.length} device(s)',
    );
  }

  void dhcpLeases(Object? status, {String title = 'DHCP leases'}) {
    final list = _asObjectList(status);
    rows(
      const ['MAC', 'IP', 'Name', 'Active', 'Reserved', 'LeaseRemaining'],
      [
        for (final d in list)
          [
            style.mac('${d['MACAddress'] ?? d['Chaddr'] ?? ''}'),
            style.ip('${d['IPAddress'] ?? d['Yiaddr'] ?? ''}'),
            style.name('${d['FriendlyName'] ?? d['Alias'] ?? ''}'),
            style.yesNo(d['Active']),
            style.reserved(d['Reserved']),
            style.muted('${d['LeaseTimeRemaining'] ?? ''}'),
          ],
      ],
      title: '$title (${list.length})',
    );
  }

  void portForwards(Object? status) {
    final rules = <Map<String, dynamic>>[];
    if (status is Map) {
      for (final value in status.values) {
        final map = _asMap(value);
        if (map != null) {
          rules.add(map);
        }
      }
    } else if (status is List) {
      rules.addAll(_asObjectList(status));
    }
    rows(
      const ['Enable', 'Name', 'Protocol', 'ExtPort', 'DestIP', 'DestPort'],
      [
        for (final r in rules)
          [
            style.yesNo(r['Enable']),
            style.name('${r['Description'] ?? r['Id'] ?? r['Name'] ?? ''}'),
            style.muted('${r['Protocol'] ?? ''}'),
            '${r['ExternalPort'] ?? r['ExternalPortEndRange'] ?? ''}',
            style.ip(
              // NOTE: We ignore line length here because it's hard to break up.
              // ignore: lines_longer_than_80_chars
              '${r['DestinationIPAddress'] ?? r['DestinationMACAddress'] ?? ''}',
            ),
            '${r['InternalPort'] ?? r['DestinationPort'] ?? ''}',
          ],
      ],
      title: rules.isEmpty ? null : '${rules.length} port forward(s)',
    );
  }

  void topology(Object? status) {
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
    if (roots.isEmpty) {
      stdout.writeln(style.muted('(empty topology)'));
      return;
    }
    for (final root in roots) {
      _printTopologyNode(root, '', '');
    }
  }

  /// Best-effort pretty print for raw `call` responses.
  void rawCall(Map<String, dynamic> result) {
    final status = result['status'];
    final data = result['data'];

    if (status is List && status.isNotEmpty && status.first is Map) {
      devices(status);
      return;
    }
    if (status is Map &&
        (status.containsKey('wifi') || status.containsKey('ethernet'))) {
      devices(status);
      return;
    }
    final map = _asMap(data) ?? _asMap(status);
    if (map != null && map.values.every(_isScalar)) {
      keyValues(map);
      return;
    }
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
  }

  void _printTopologyNode(
    Map<String, dynamic> node,
    String prefix,
    String childPrefix,
  ) {
    stdout.writeln('${style.branch(prefix)}${_topologyLabel(node)}');

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
      _printTopologyNode(
        child,
        '$childPrefix$branch',
        '$childPrefix$nextChild',
      );
    }
  }

  String _topologyLabel(Map<String, dynamic> node) {
    final name = node['Name']?.toString() ?? node['Key']?.toString() ?? '?';
    final bits = <String>[style.name(name)];
    final ssid = node['SSID']?.toString();
    if (ssid != null && ssid.isNotEmpty) {
      bits.add(style.ssid('ssid=$ssid'));
    }
    final ip = bestIpv4(node);
    if (ip.isNotEmpty) {
      bits.add(style.ip(ip));
    }
    final mac = node['PhysAddress']?.toString();
    if (mac != null && mac.isNotEmpty && mac != name) {
      bits.add(style.mac(mac));
    }
    final active = node['Active'];
    if (active is bool) {
      bits.add(style.upDown(active));
    }
    return bits.join('  ');
  }

  static bool _deviceReserved(Map<String, dynamic> device) {
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

  static List<Map<String, dynamic>> _asObjectList(Object? status) {
    if (status is List) {
      return [
        for (final item in status)
          if (item is Map<String, dynamic>)
            item
          else if (item is Map)
            Map<String, dynamic>.from(item),
      ];
    }
    if (status is Map) {
      return [
        for (final value in status.values)
          if (value is Map<String, dynamic>)
            value
          else if (value is Map)
            Map<String, dynamic>.from(value),
      ];
    }
    return const [];
  }

  static List<Map<String, dynamic>> flattenDevices(Object? status) {
    if (status is List) {
      return [
        for (final item in status)
          if (item is Map<String, dynamic>)
            item
          else if (item is Map)
            Map<String, dynamic>.from(item),
      ];
    }
    if (status is Map) {
      final out = <Map<String, dynamic>>[];
      for (final value in status.values) {
        if (value is List) {
          out.addAll(flattenDevices(value));
        }
      }
      return out;
    }
    return const [];
  }

  static String bestIpv4(Map<String, dynamic> device) {
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

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static bool _isScalar(Object? value) =>
      value == null || value is num || value is bool || value is String;

  static String _cell(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is bool || value is num || value is String) {
      return '$value';
    }
    return const JsonEncoder().convert(value);
  }
}
