import 'package:sah/src/api/sah_client.dart';
import 'package:sah/src/api/sah_session.dart';

/// Shared CLI options → [SahClient].
class const SahConfig({
  required final String host,
  final String? contextId,
  final String? cookie,
  final bool jsonOutput = false,
  final bool verbose = false,
  final bool quiet = false,
}) {
  /// Default LAN IP on KPN Experia boxes. Override with `-H` / `--host`.
  static const defaultHost = '192.168.2.254';

  SahClient createClient() {
    final client = SahClient(host: host);
    final saved = SahSession.load();

    final effectiveHost = host;
    final ctx =
        contextId ??
        (saved != null && saved.host == effectiveHost ? saved.contextId : null);
    final cook =
        cookie ??
        (saved != null && saved.host == effectiveHost ? saved.cookie : null);

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
