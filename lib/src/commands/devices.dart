import 'package:args/command_runner.dart';
import 'package:sah/src/commands/sah_command.dart';

class DevicesCommand() extends Command<int>
    with SahCommandContext, TableCommandOptions, ActiveFlagOption {
  this {
    addTableOptions();
    addActiveFlag(
      help: 'Only devices with Active==true (wifi + ethernet).',
    );
  }

  @override
  String get name => 'devices';

  @override
  String get description => 'List hosts known to the gateway (Devices.get).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.hosts(activeOnly: activeOnly);
    final status = result['status'] ?? result;
    out.devices(status);
    return 0;
  });
}
