import 'package:args/command_runner.dart';
import 'package:sah/src/api/sah_credentials.dart';
import 'package:sah/src/api/sah_session.dart';

class LogoutCommand() extends Command<int> {
  @override
  String get name => 'logout';

  @override
  String get description =>
      'Delete the saved session and stored credentials.';

  @override
  Future<int> run() async {
    SahSession.clear();
    SahCredentials.clear();
    // NOTE: plain print; logout has no SahOutput / style wiring.
    // ignore: avoid_print
    print(
      'Cleared ${SahSession.defaultFile().path} and '
      '${SahCredentials.defaultFile().path}',
    );
    return 0;
  }
}
