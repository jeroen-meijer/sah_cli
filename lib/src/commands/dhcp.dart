import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/commands/sah_command.dart';
import 'package:sah/src/config.dart';
import 'package:sah/src/device_query.dart';
import 'package:sah/src/dhcp_leases.dart';
import 'package:sah/src/host_row.dart';
import 'package:sah/src/output.dart';
import 'package:sah/src/topology_picker.dart';

class DhcpCommand() extends Command<int> {
  this {
    addSubcommand(DhcpLeasesCommand());
    addSubcommand(DhcpStaticCommand());
    addSubcommand(DhcpReserveCommand());
    addSubcommand(DhcpUnreserveCommand());
  }

  @override
  String get name => 'dhcp';

  @override
  String get description =>
      'DHCP leases and static IP reservations (SoftAtHome DHCPv4 pool).';
}

mixin _DhcpPoolOption on Command<int> {
  void addPoolOption() {
    argParser.addOption(
      'pool',
      defaultsTo: SahClient.defaultDhcpPool,
      help: 'SoftAtHome DHCP pool object path.',
    );
  }

  String get pool => argResults!['pool'] as String;
}

class DhcpLeasesCommand()
    extends Command<int>
    with
        SahCommandContext,
        TableCommandOptions,
        _DhcpPoolOption,
        ActiveFlagOption {
  this {
    addTableOptions();
    addPoolOption();
    addActiveFlag(help: 'Only leases with Active==true.');
  }

  @override
  String get name => 'leases';

  @override
  String get description => 'List dynamic DHCP leases (getLeases).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.dhcpLeases(pool: pool);
    final status = result['status'] ?? result;
    out.dhcpLeases(status, activeOnly: activeOnly);
    return 0;
  });
}

class DhcpStaticCommand()
    extends Command<int>
    with
        SahCommandContext,
        TableCommandOptions,
        _DhcpPoolOption,
        ActiveFlagOption {
  this {
    addTableOptions();
    addPoolOption();
    addActiveFlag(help: 'Only reservations with Active==true.');
  }

  @override
  String get name => 'static';

  @override
  String get description => 'List static DHCP reservations (getStaticLeases).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final staticResult = await client.dhcpStaticLeases(pool: pool);
    final leasesResult = await client.dhcpLeases(pool: pool);
    final hostsResult = await client.hosts();

    final staticRows = flattenDhcpLeases(
      staticResult['status'] ?? staticResult,
    );
    final dynamicLeases = flattenDhcpLeases(
      leasesResult['status'] ?? leasesResult,
    );
    final hosts = SahOutput.flattenDevices(
      hostsResult['status'] ?? hostsResult,
    );
    final rows = enrichStaticDhcpLeases(
      staticRows: staticRows,
      dynamicLeases: dynamicLeases,
      hosts: hosts,
    );

    out.dhcpLeases(
      staticResult['status'] ?? staticResult,
      title: 'Static DHCP leases',
      activeOnly: activeOnly,
      rows: rows,
    );
    return 0;
  });
}

class DhcpReserveCommand()
    extends Command<int>
    with SahCommandContext, _DhcpPoolOption, ActiveFlagOption {
  this {
    addPoolOption();
    addActiveFlag(
      help: 'Only match active wifi/ethernet hosts when resolving <query>, '
          'or prune inactive topology leaves with --interactive.',
    );
    argParser
      ..addFlag(
        'interactive',
        abbr: 'i',
        negatable: false,
        help: 'Pick a device from the LAN topology (TTY). '
            'Do not pass <query> or [ip].',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Print the planned SoftAtHome call; do not mutate the gateway.',
      );
  }

  @override
  String get name => 'reserve';

  @override
  String get invocation =>
      'sah dhcp reserve (<query> [ip] | --interactive)';

  @override
  String get description =>
      'Reserve a static DHCP lease (addStaticLease). Mutates the gateway. '
      '<query> matches name, MAC, or IP (like find). Optional [ip] overrides '
      "the address to lock; omit to use the device's current IPv4. "
      'Use -i/--interactive to pick from the topology tree.';

  @override
  Future<int> run() {
    final interactive = argResults!['interactive'] as bool;
    final rest = argResults!.rest;
    final dryRun = argResults!['dry-run'] as bool;

    if (interactive) {
      if (rest.isNotEmpty) {
        usageException(
          'Do not pass <query> or [ip] with --interactive.',
        );
      }
      return withClient((client, config, out) async {
        if (config.jsonOutput) {
          stderr.writeln(
            '${out.style.errorLabel()} --interactive cannot be used '
            'with --json\n'
            '  ${out.style.tipLabel()} drop --json, or pass <query> instead',
          );
          return 64;
        }
        final topoResult = await client.topology();
        var status = topoResult['status'] ?? topoResult;
        if (activeOnly) {
          status = filterActiveTopology(status) ?? status;
        }
        final picked = await pickTopologyDevice(
          status: status,
          style: out.style,
        );
        if (picked == null) {
          stderr.writeln('Cancelled.');
          return 1;
        }
        final hostsResult = await client.hosts(activeOnly: activeOnly);
        final hosts = SahOutput.flattenDevices(
          hostsResult['status'] ?? hostsResult,
        );
        return await _applyReserve(
          client: client,
          config: config,
          out: out,
          pool: pool,
          device: picked,
          ipOverride: null,
          hosts: hosts,
          dryRun: dryRun,
          resolveLabel: 'interactive',
        );
      });
    }

    if (rest.isEmpty || rest.length > 2) {
      usageException('Expected: $invocation');
    }
    final query = rest[0];
    final ipOverride = rest.length == 2 ? rest[1] : null;
    if (ipOverride != null && !DeviceQuery.looksLikeIpv4(ipOverride)) {
      usageException('Optional [ip] must be a dotted IPv4 address.');
    }

    return withClient((client, config, out) async {
      final hostsResult = await client.hosts(activeOnly: activeOnly);
      final hosts = SahOutput.flattenDevices(
        hostsResult['status'] ?? hostsResult,
      );
      final resolved = _matchUniqueDevice(query, hosts);
      if (resolved == null) {
        return 1;
      }
      return await _applyReserve(
        client: client,
        config: config,
        out: out,
        pool: pool,
        device: resolved,
        ipOverride: ipOverride,
        hosts: hosts,
        dryRun: dryRun,
        resolveLabel: query,
      );
    });
  }
}

Future<int> _applyReserve({
  required SahClient client,
  required SahConfig config,
  required SahOutput out,
  required String pool,
  required Map<String, dynamic> device,
  required String? ipOverride,
  required List<Map<String, dynamic>> hosts,
  required bool dryRun,
  required String resolveLabel,
}) async {
  final mac = DeviceQuery.macOf(device);
  if (mac.isEmpty) {
    stderr.writeln('Matched device has no MAC/PhysAddress.');
    return 1;
  }

  final currentIp = SahOutput.bestIpv4(device);
  final reservedIp = ipOverride ?? currentIp;
  if (reservedIp.isEmpty) {
    stderr.writeln(
      'Device has no IPv4 yet; pass an explicit address: '
      'sah dhcp reserve $resolveLabel <ip>',
    );
    return 64;
  }

  if (!config.jsonOutput) {
    stderr.writeln(
      'Resolved "$resolveLabel" → ${device['Name']} ($mac) '
      'current=${currentIp.isEmpty ? "(none)" : currentIp}',
    );
  }

  final conflict = await _reservationConflict(
    client,
    pool: pool,
    mac: mac,
    ip: reservedIp,
    hosts: hosts,
  );
  if (conflict != null) {
    if (conflict.alreadyReserved) {
      out.emit(
        {
          'alreadyReserved': true,
          'MACAddress': mac,
          'IPAddress': reservedIp,
        },
        () {
          stdout.writeln('Already reserved: $reservedIp for $mac');
        },
      );
      return 0;
    }
    stderr.writeln(conflict.message);
    return 1;
  }

  final params = <String, String>{
    'MACAddress': mac,
    'IPAddress': reservedIp,
  };
  if (dryRun) {
    out.emit(
      {
        'dryRun': true,
        'service': pool,
        'method': 'addStaticLease',
        'parameters': params,
      },
      () {
        stdout
          ..writeln('Dry run: would call:')
          ..writeln('  $pool::addStaticLease $params');
      },
    );
    return 0;
  }

  final result = await client.dhcpAddStaticLease(
    macAddress: mac,
    ipAddress: reservedIp,
    pool: pool,
  );
  out.emit(result, () {
    stdout.writeln('Reserved $reservedIp for $mac');
  });
  return 0;
}

class DhcpUnreserveCommand()
    extends Command<int>
    with SahCommandContext, _DhcpPoolOption, ActiveFlagOption {
  this {
    addPoolOption();
    addActiveFlag(
      help: 'Only match active wifi/ethernet hosts when resolving <query>.',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Print the planned SoftAtHome call; do not mutate the gateway.',
    );
  }

  @override
  String get name => 'unreserve';

  @override
  String get invocation => 'sah dhcp unreserve <query>';

  @override
  String get description =>
      'Remove a static DHCP lease (deleteStaticLease). Mutates the gateway. '
      '<query> matches name, MAC, or IP (like find).';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Expected: $invocation');
    }
    final query = rest[0];
    final dryRun = argResults!['dry-run'] as bool;

    return withClient((client, config, out) async {
      final hostsResult = await client.hosts(activeOnly: activeOnly);
      final hosts = SahOutput.flattenDevices(
        hostsResult['status'] ?? hostsResult,
      );
      final resolved = _matchUniqueDevice(query, hosts);
      if (resolved == null) {
        return 1;
      }

      final mac = DeviceQuery.macOf(resolved);
      if (mac.isEmpty) {
        stderr.writeln('Matched device has no MAC/PhysAddress.');
        return 1;
      }

      if (!config.jsonOutput) {
        stderr.writeln(
          'Resolved "$query" → ${resolved['Name']} ($mac)',
        );
      }

      final params = {'MACAddress': mac};
      if (dryRun) {
        out.emit(
          {
            'dryRun': true,
            'service': pool,
            'method': 'deleteStaticLease',
            'parameters': params,
          },
          () {
            stdout
              ..writeln('Dry run: would call:')
              ..writeln('  $pool::deleteStaticLease $params');
          },
        );
        return 0;
      }

      final result = await client.dhcpDeleteStaticLease(
        macAddress: mac,
        pool: pool,
      );
      out.emit(result, () {
        stdout.writeln('Removed reservation for $mac');
      });
      return 0;
    });
  }
}

class const _ReservationConflict(
  final String message, {
  final bool alreadyReserved = false,
});

Future<_ReservationConflict?> _reservationConflict(
  SahClient client, {
  required String pool,
  required String mac,
  required String ip,
  required List<Map<String, dynamic>> hosts,
}) async {
  final wantMac = DeviceQuery.normalizeMac(mac);
  final staticResult = await client.dhcpStaticLeases(pool: pool);
  final staticRows = _objectRows(staticResult['status'] ?? staticResult);
  for (final row in staticRows) {
    final rowIp = '${row['IPAddress'] ?? row['Yiaddr'] ?? ''}';
    final rowMac = DeviceQuery.normalizeMac(
      '${row['MACAddress'] ?? row['Chaddr'] ?? ''}',
    );
    if (rowMac == wantMac && rowIp == ip) {
      return const _ReservationConflict(
        'already reserved',
        alreadyReserved: true,
      );
    }
    if (rowMac == wantMac && rowIp.isNotEmpty && rowIp != ip) {
      return _ReservationConflict(
        'MAC $mac already reserved for $rowIp; '
        'run `sah dhcp unreserve` first.',
      );
    }
    if (rowIp == ip && rowMac.isNotEmpty && rowMac != wantMac) {
      return _ReservationConflict(
        'IP $ip already reserved for ${row['MACAddress'] ?? row['Chaddr']}.',
      );
    }
  }

  for (final host in hosts) {
    if (SahOutput.bestIpv4(host) != ip) {
      continue;
    }
    final hostMac = DeviceQuery.normalizeMac(DeviceQuery.macOf(host));
    if (hostMac.isNotEmpty && hostMac != wantMac) {
      return _ReservationConflict(
        'IP $ip currently used by ${host['Name'] ?? hostMac} ($hostMac).',
      );
    }
  }
  return null;
}

Map<String, dynamic>? _matchUniqueDevice(
  String query,
  List<Map<String, dynamic>> hosts,
) {
  final matched = DeviceQuery(query).filter(hosts);
  if (matched.isEmpty) {
    stderr.writeln('No device matched "$query".');
    return null;
  }
  if (matched.length > 1) {
    stderr.writeln(
      'Ambiguous "$query" matched ${matched.length} devices; '
      'use a more specific name, MAC, or IP:',
    );
    for (final d in matched) {
      stderr.writeln(
        '  - ${d['Name']}  ${SahOutput.bestIpv4(d)}  '
        '${DeviceQuery.macOf(d)}',
      );
    }
    return null;
  }
  return matched.single;
}

List<Map<String, dynamic>> _objectRows(Object? status) {
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
