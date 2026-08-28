import 'dart:io';

import 'package:sah/sah.dart';

Future<void> main(List<String> args) async {
  await _flushThenExit(await SahCommandRunner().run(args));
}

Future<void> _flushThenExit(int status) =>
    Future.wait<void>([stdout.close(), stderr.close()])
        .then<void>((_) => exit(status));
