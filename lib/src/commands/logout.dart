import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_session.dart';

class LogoutCommand() extends Command<int> {
  @override
  String get name => 'logout';

  @override
  String get description => 'Delete the saved session file.';

  @override
  Future<int> run() async {
    SahSession.clear();
    // NOTE: We ignore print here once since we don't need fancy output.
    // ignore: avoid_print
    print('Cleared ${SahSession.defaultFile().path}');
    return 0;
  }
}
