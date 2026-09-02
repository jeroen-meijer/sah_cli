import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/api/sah_exception.dart';
import 'package:sah/src/cli_error.dart';
import 'package:sah/src/config.dart';
import 'package:sah/src/output.dart';
import 'package:sah/src/style.dart';

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
      noColor: global['no-color'] as bool,
    );
  }

  SahOutput outputFor(SahConfig config) => SahOutput(
    config,
    style: SahStyle(color: config.useColor),
  );

  Future<int> withClient(
    Future<int> Function(SahClient client, SahConfig config, SahOutput out) run,
  ) async {
    final config = readConfig();
    final client = config.createClient();
    final out = outputFor(config);
    try {
      return await run(client, config, out);
    } on SahException catch (e) {
      reportCliError(e, style: out.style);
      if (config.verbose && e.body != null) {
        stderr.writeln(const JsonEncoder.withIndent('  ').convert(e.body));
      }
      return 1;
    } finally {
      client.close();
    }
  }
}

/// Adds `--sort-by` / `--fields` / `--no-truncate` for table commands.
mixin TableCommandOptions on SahCommandContext {
  void addTableOptions() {
    argParser
      ..addMultiOption(
        'sort-by',
        help:
            'Sort by column id(s), in order. Prefix - for descending '
            '(e.g. -FirstSeen,Name). Also applies to --json.',
      )
      ..addMultiOption(
        'fields',
        help:
            'Only include these columns, in this order '
            '(e.g. Name,IP,MAC). Also projects --json.',
      )
      ..addFlag(
        'no-truncate',
        negatable: false,
        help:
            'Do not shrink or drop columns to fit the terminal width.',
      );
  }

  List<String> get tableSortBy =>
      List<String>.from(argResults!['sort-by'] as List);

  List<String>? get tableFields {
    if (!argResults!.wasParsed('fields')) {
      return null;
    }
    final fields = List<String>.from(argResults!['fields'] as List);
    if (fields.isEmpty) {
      usageException('--fields must include at least one column');
    }
    return fields;
  }

  bool get tableNoTruncate => argResults!['no-truncate'] as bool;

  @override
  SahOutput outputFor(SahConfig config) => SahOutput(
    config,
    style: SahStyle(color: config.useColor),
    sortBy: tableSortBy,
    fields: tableFields,
    truncate: !tableNoTruncate,
  );
}
