import 'package:args/command_runner.dart';
import 'package:sah/src/commands/sah_command.dart';

class PortsCommand() extends Command<int> with SahCommandContext {
  @override
  String get name => 'ports';

  @override
  String get description =>
      'List port forwarding rules (Firewall.getPortForwarding).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.portForwarding();
    final status = result['status'] ?? result;
    out.emit(status, () => out.portForwards(status));
    return 0;
  });
}

class WifiCommand() extends Command<int> with SahCommandContext {
  @override
  String get name => 'wifi';

  @override
  String get description => 'Show Wi‑Fi radio status (NMC.Wifi.get).';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final result = await client.wifiStatus();
    final status = result['status'] ?? result;
    out.emit(status, () => out.deviceInfo(status));
    return 0;
  });
}

class FirewallCommand() extends Command<int> with SahCommandContext {
  @override
  String get name => 'firewall';

  @override
  String get description => 'Show firewall level and DMZ settings.';

  @override
  Future<int> run() => withClient((client, config, out) async {
    final level = await client.firewallLevel();
    final dmz = await client.firewallDmz();
    final payload = <String, dynamic>{
      'level': level['status'] ?? level,
      'dmz': dmz['status'] ?? dmz,
    };
    out.emit(payload, () {
      final fields = <String, Object?>{'Level': payload['level']};
      final dmz = payload['dmz'];
      if (dmz is Map) {
        for (final e in dmz.entries) {
          fields['DMZ.${e.key}'] = e.value;
        }
      } else {
        fields['DMZ'] = dmz;
      }
      out.keyValues(fields);
    });
    return 0;
  });
}
