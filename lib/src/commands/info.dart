import 'package:args/command_runner.dart';
import 'package:sah/src/commands/sah_command.dart';

class InfoCommand() extends Command<int> with SahCommandContext {
  @override
  String get name => 'info';

  @override
  String get description => 'Show DeviceInfo from the gateway.';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.deviceInfo();
    final status = result['status'] ?? result;
    out.emit(status, () => out.deviceInfo(status));
    return 0;
  });
}

class WanCommand() extends Command<int> with SahCommandContext {
  @override
  String get name => 'wan';

  @override
  String get description => 'Show WAN status (NMC.getWANStatus).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.wanStatus();
    final payload = result['data'] ?? result['status'] ?? result;
    out.emit(payload, () => out.wanStatus(result));
    return 0;
  });
}

class TopologyCommand() extends Command<int> with SahCommandContext {
  @override
  String get name => 'topology';

  @override
  String get description => 'Show LAN topology (Devices.Device.lan.topology).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.topology();
    final status = result['status'] ?? result;
    out.emit(status, () => out.topology(status));
    return 0;
  });
}
