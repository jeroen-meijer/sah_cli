import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/api/sah_exception.dart';
import 'package:sah/src/api/sah_session.dart';
import 'package:sah/src/commands/sah_command.dart';

class LoginCommand() extends Command<int> with SahCommandContext {
  this {
    argParser
      ..addOption(
        'password',
        abbr: 'p',
        help: 'Admin password. Falls back to SAH_PASSWORD env var.',
      )
      ..addOption(
        'username',
        abbr: 'u',
        defaultsTo: 'admin',
        help: 'Admin username (KPN default: admin).',
      )
      ..addFlag(
        'no-save',
        negatable: false,
        help: 'Do not write session to ~/.config/sah/session.json',
      );
  }

  @override
  String get name => 'login';

  @override
  String get description =>
      'Authenticate with SoftAtHome createContext and save the session.';

  @override
  Future<int> run() async {
    final password =
        (argResults!['password'] as String?) ??
        Platform.environment['SAH_PASSWORD'];
    if (password == null || password.isEmpty) {
      stderr.writeln('Password required via --password or SAH_PASSWORD.');
      return 64;
    }

    final config = readConfig();
    final username = argResults!['username'] as String;
    final client = SahClient(host: config.host, username: username);

    try {
      final session = await client.login(password);
      if (argResults!['no-save'] != true) {
        session.save();
        stderr.writeln('Session saved to ${SahSession.defaultFile().path}');
      }
      final payload = <String, String>{
        'host': session.host,
        'contextId': session.contextId,
        'cookie': session.cookie,
      };
      outputFor(config).emit(payload, () {
        stdout
          ..writeln('Logged in to ${session.host}')
          ..writeln('contextId: ${session.contextId}');
      });
      return 0;
    } on SahException catch (e) {
      stderr.writeln(e.userMessage);
      if (config.verbose && e.body != null) {
        stderr.writeln(e.body);
      }
      return 1;
    } finally {
      client.close();
    }
  }
}
