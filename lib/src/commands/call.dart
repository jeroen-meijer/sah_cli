import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:sah/src/commands/sah_command.dart';

class CallCommand() extends Command<int> with SahCommandContext {
  @override
  String get name => 'call';

  @override
  String get description =>
      'Raw SoftAtHome call: sah call <service> <method> [parameters-json]';

  @override
  String get invocation => 'sah call <service> <method> [parameters-json]';

  @override
  Future<int> run() {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      usageException('Expected: call <service> <method> [parameters-json]');
    }

    final service = rest[0];
    final method = rest[1];
    Object? parameters = <String, dynamic>{};
    if (rest.length >= 3) {
      parameters = jsonDecode(rest.sublist(2).join(' '));
    }

    return withClient((client, config, out) async {
      final result = await client.call(
        service: service,
        method: method,
        parameters: parameters,
      );
      out.emit(result, () => out.rawCall(result));
      return 0;
    });
  }
}
