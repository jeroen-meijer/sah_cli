import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/api/sah_exception.dart';
import 'package:sah/src/config.dart';
import 'package:sah/src/output.dart';

mixin SahCommandContext on Command<int> {
  SahConfig readConfig() {
    final global = globalResults!;
    return SahConfig(
      host: global['host'] as String,
      contextId: global['context'] as String?,
      cookie: global['cookie'] as String?,
      jsonOutput: global['json'] as bool,
      verbose: global['verbose'] as bool,
      quiet: global['quiet'] as bool,
    );
  }

  SahOutput outputFor(SahConfig config) => SahOutput(config);

  Future<int> withClient(
    Future<int> Function(SahClient client, SahConfig config, SahOutput out) run,
  ) async {
    final config = readConfig();
    final client = config.createClient();
    final out = outputFor(config);
    try {
      return await run(client, config, out);
    } on SahException catch (e) {
      stderr.writeln(e.userMessage);
      if (config.verbose && e.body != null) {
        stderr.writeln(const JsonEncoder.withIndent('  ').convert(e.body));
      }
      return 1;
    } finally {
      client.close();
    }
  }
}
