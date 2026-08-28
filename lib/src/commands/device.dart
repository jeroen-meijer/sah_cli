import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:sah/src/commands/sah_command.dart';
import 'package:sah/src/device_query.dart';
import 'package:sah/src/output.dart';

class DeviceCommand() extends Command<int> {
  this {
    addSubcommand(RenameDeviceCommand());
  }

  @override
  String get name => 'device';

  @override
  String get description => 'Device management commands.';
}

class RenameDeviceCommand() extends Command<int> with SahCommandContext {
  this {
    argParser.addFlag(
      'apply',
      negatable: false,
      help: 'Actually mutate the gateway (default: dry-run only).',
    );
  }

  @override
  String get name => 'rename';

  @override
  String get invocation => 'sah device rename <query> <newName>';

  @override
  String get description =>
      'Rename a device in the gateway UI (Devices.Device.<key>:setName).';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      usageException('Expected: $invocation');
    }

    final query = rest[0];
    final newName = rest.sublist(1).join(' ').trim();

    return withClient((client, config, out) async {
      final devices = await client.devices(
        expression: 'not interface and not self and not voice',
      );
      final all = SahOutput.flattenDevices(devices['status'] ?? devices);
      final matched = all.where((d) => DeviceQuery(query).matches(d)).toList();

      if (matched.isEmpty) {
        stderr.writeln('No devices matched: "$query"');
        return 1;
      }
      if (matched.length != 1) {
        stderr.writeln(
          'Ambiguous "$query": matched ${matched.length} devices. '
          'Use a more specific query.',
        );
        for (final d in matched) {
          stderr.writeln(
            '  - ${d['Name'] ?? d['Key'] ?? ''}  '
            '${SahOutput.bestIpv4(d)}  ${DeviceQuery.macOf(d)}',
          );
        }
        return 2;
      }

      final device = matched.single;
      final deviceKey =
          device['Key']?.toString() ?? device['PhysAddress']?.toString() ?? '';
      if (deviceKey.isEmpty) {
        stderr.writeln('Matched device has no Key/PhysAddress for setName.');
        return 1;
      }

      final dryPayload = <String, Object>{
        'dryRun': true,
        'service': 'Devices.Device.$deviceKey',
        'method': 'setName',
        'parameters': {'name': newName, 'source': 'webui'},
      };

      if (argResults?['apply'] != true) {
        out.emit(dryPayload, () {
          stdout
            ..writeln('Dry run: would call:')
            ..writeln(
              '  Devices.Device.$deviceKey::setName '
              'name="$newName" source=webui',
            );
        });
        return 0;
      }

      final result = await client.setDeviceName(
        deviceKey: deviceKey,
        name: newName,
      );

      out.emit(result, () {
        stdout.writeln('Renamed ${device['Name'] ?? deviceKey} -> $newName');
      });
      return 0;
    });
  }
}
