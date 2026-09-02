import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/commands/sah_command.dart';
import 'package:sah/src/device_query.dart';
import 'package:sah/src/output.dart';

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
    with SahCommandContext, TableCommandOptions, _DhcpPoolOption {
  this {
    addTableOptions();
    addPoolOption();
  }

  @override
  String get name => 'leases';

  @override
  String get description => 'List dynamic DHCP leases (getLeases).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.dhcpLeases(pool: pool);
    final status = result['status'] ?? result;
    out.dhcpLeases(status);
    return 0;
  });
}

class DhcpStaticCommand()
    extends Command<int>
    with SahCommandContext, TableCommandOptions, _DhcpPoolOption {
  this {
    addTableOptions();
    addPoolOption();
  }

  @override
  String get name => 'static';

  @override
  String get description => 'List static DHCP reservations (getStaticLeases).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.dhcpStaticLeases(pool: pool);
    final status = result['status'] ?? result;
    out.dhcpLeases(status, title: 'Static DHCP leases');
    return 0;
  });
}

class DhcpReserveCommand()
    extends Command<int>
    with SahCommandContext, _DhcpPoolOption {
  this {
    addPoolOption();
    argParser
      ..addOption(
        'mac',
        abbr: 'm',
        help: 'Device MAC address (AA:BB:… or as shown by sah find).',
      )
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Resolve MAC by device name substring (via Devices.get).',
      )
      ..addOption(
        'ip',
        abbr: 'i',
        help: "IPv4 to reserve. Defaults to the device's current IPv4.",
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
  String get description =>
      'Reserve a static DHCP lease (addStaticLease). Mutates the gateway.';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final macOpt = argResults!['mac'] as String?;
    final nameOpt = argResults!['name'] as String?;
    var ip = argResults!['ip'] as String?;
    final dryRun = argResults!['dry-run'] as bool;

    if ((macOpt == null || macOpt.isEmpty) &&
        (nameOpt == null || nameOpt.isEmpty)) {
      usageException('Provide --mac and/or --name');
    }

    late final String mac;
    if (macOpt != null && macOpt.isNotEmpty) {
      mac = macOpt;
    } else {
      final resolved = await _resolveDevice(client, nameOpt!);
      if (resolved == null) {
        stderr.writeln('No device matched name "$nameOpt".');
        return 1;
      }
      mac = DeviceQuery.macOf(resolved);
      ip ??= SahOutput.bestIpv4(resolved);
      if (!config.jsonOutput) {
        stderr.writeln(
          'Resolved "$nameOpt" → ${resolved['Name']} ($mac) '
          'ip=${ip.isEmpty ? "(none)" : ip}',
        );
      }
    }

    final reservedIp = ip;
    if (reservedIp == null || reservedIp.isEmpty) {
      stderr.writeln('IP required via --ip (device has no IPv4 yet).');
      return 64;
    }

    final params = <String, String>{'MACAddress': mac, 'IPAddress': reservedIp};
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
  });
}

class DhcpUnreserveCommand()
    extends Command<int>
    with SahCommandContext, _DhcpPoolOption {
  this {
    addPoolOption();
    argParser
      ..addOption('mac', abbr: 'm', help: 'MAC address to unreserve.')
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Resolve MAC by device name substring.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Print the planned SoftAtHome call; do not mutate the gateway.',
      );
  }

  @override
  String get name => 'unreserve';

  @override
  String get description =>
      'Remove a static DHCP lease (deleteStaticLease). Mutates the gateway.';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final macOpt = argResults!['mac'] as String?;
    final nameOpt = argResults!['name'] as String?;
    final dryRun = argResults!['dry-run'] as bool;

    if ((macOpt == null || macOpt.isEmpty) &&
        (nameOpt == null || nameOpt.isEmpty)) {
      usageException('Provide --mac and/or --name');
    }

    late final String mac;
    if (macOpt != null && macOpt.isNotEmpty) {
      mac = macOpt;
    } else {
      final resolved = await _resolveDevice(client, nameOpt!);
      if (resolved == null) {
        stderr.writeln('No device matched name "$nameOpt".');
        return 1;
      }
      mac = DeviceQuery.macOf(resolved);
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

Future<Map<String, dynamic>?> _resolveDevice(
  SahClient client,
  String nameQuery,
) async {
  final result = await client.devices(
    expression: 'not interface and not self and not voice',
  );
  final all = SahOutput.flattenDevices(result['status'] ?? result);
  final query = DeviceQuery(nameQuery);
  final matched = all.where(query.matches).toList();
  if (matched.isEmpty) {
    return null;
  }
  if (matched.length > 1) {
    stderr.writeln(
      'Ambiguous name "$nameQuery" matched ${matched.length} devices; '
      'pass --mac instead:',
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
