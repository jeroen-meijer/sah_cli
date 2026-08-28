import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:sah/src/commands/commands.dart';
import 'package:sah/src/config.dart';

/// SoftAtHome gateway CLI.
class SahCommandRunner() extends CommandRunner<int> {
  this
    : super('sah', 'SoftAtHome sysbus CLI for KPN / Livebox-style gateways.') {
    argParser
      ..addOption(
        'host',
        abbr: 'H',
        defaultsTo: SahConfig.defaultHost,
        help: 'Gateway host or IP.',
      )
      ..addOption(
        'context',
        abbr: 'c',
        help: 'SoftAtHome contextID (overrides saved session).',
      )
      ..addOption(
        'cookie',
        help:
            'Cookie header value, e.g. "prefix/sessid=…" '
            '(overrides saved session).',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print machine-readable JSON instead of tables/lists.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Print extra error details.',
      )
      ..addFlag(
        'quiet',
        abbr: 'q',
        negatable: false,
        help: 'Suppress progress messages on stderr.',
      );

    addCommand(LoginCommand());
    addCommand(LogoutCommand());
    addCommand(InfoCommand());
    addCommand(WanCommand());
    addCommand(DevicesCommand());
    addCommand(FindCommand());
    addCommand(TopologyCommand());
    addCommand(DhcpCommand());
    addCommand(PortsCommand());
    addCommand(WifiCommand());
    addCommand(FirewallCommand());
    addCommand(DeviceCommand());
    addCommand(SpeedtestCommand());
    addCommand(CallCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final top = parse(args);
      final code = await runCommand(top);
      return code ?? ExitCode.success.code;
    } on UsageException catch (e) {
      stderr
        ..writeln(e.message)
        ..writeln(e.usage);
      return ExitCode.usage.code;
    } on FormatException catch (e) {
      stderr.writeln(e.message);
      return ExitCode.usage.code;
    }
  }
}
