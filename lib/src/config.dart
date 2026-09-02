import 'dart:io';

import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/api/sah_credentials.dart';
import 'package:sah/src/api/sah_session.dart';

/// Shared CLI options → [SahClient].
class const SahConfig({
  required final String host,
  final String? contextId,
  final String? cookie,
  final bool jsonOutput = false,
  final bool verbose = false,
  final bool quiet = false,

  /// When true, force plain text (overrides TTY auto-detect).
  final bool noColor = false,
}) {
  /// Default LAN IP on KPN Experia boxes. Override with `-H` / `--host`.
  static const defaultHost = '192.168.2.254';

  /// Whether human output should use ANSI styles.
  bool get useColor =>
      !noColor &&
      stdout.supportsAnsiEscapes &&
      Platform.environment['NO_COLOR'] == null;

  SahClient createClient() {
    final saved = SahSession.load();
    final credentials = SahCredentials.load();
    final envPassword = Platform.environment['SAH_PASSWORD'];

    final effectiveHost = host;
    final ctx =
        contextId ??
        (saved != null && saved.host == effectiveHost ? saved.contextId : null);
    final cook =
        cookie ??
        (saved != null && saved.host == effectiveHost ? saved.cookie : null);

    final password = () {
      if (envPassword != null && envPassword.isNotEmpty) {
        return envPassword;
      }
      if (credentials != null &&
          credentials.host == effectiveHost &&
          credentials.password.isNotEmpty) {
        return credentials.password;
      }
      return null;
    }();

    final username = credentials != null && credentials.host == effectiveHost
        ? credentials.username
        : 'admin';

    final client = SahClient(
      host: effectiveHost,
      username: username,
      password: password,
      persistSession: (session) => session.save(),
    );

    if (ctx != null && cook != null) {
      client.session = SahSession(
        host: effectiveHost,
        contextId: ctx,
        cookie: cook,
      );
    }
    return client;
  }
}
