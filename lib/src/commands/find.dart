import 'package:args/command_runner.dart';
import 'package:sah/src/commands/sah_command.dart';
import 'package:sah/src/device_query.dart';
import 'package:sah/src/output.dart';

/// Search hosts by name / MAC / IP substring.
class FindCommand() extends Command<int> with SahCommandContext {
  this {
    argParser.addFlag(
      'active',
      abbr: 'a',
      negatable: false,
      help: 'Only search currently active wifi/ethernet hosts.',
    );
  }

  @override
  String get name => 'find';

  @override
  String get description =>
      'Find hosts by name, MAC, or IP substring (case-insensitive).';

  @override
  String get invocation => 'sah find <query>';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Expected: find <query>');
    }
    final query = DeviceQuery(rest.join(' '));

    return withClient((client, config, out) async {
      final result = argResults!['active'] == true
          ? await client.activeDevices()
          : await client.devices(
              expression: 'not interface and not self and not voice',
            );
      final all = SahOutput.flattenDevices(result['status'] ?? result);
      final matched = all.where(query.matches).toList();
      out.emit(matched, () => out.devices(matched));
      return matched.isEmpty ? 1 : 0;
    });
  }
}
