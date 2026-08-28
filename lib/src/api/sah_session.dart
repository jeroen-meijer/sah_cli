import 'dart:convert';
import 'dart:io';

/// Persisted SoftAtHome session for the CLI.
class const SahSession({
  required final String host,
  required final String contextId,

  /// Full `Cookie` header value (e.g. `a1b2c3d4/sessid=…`).
  required final String cookie,
}) {
  factory fromJson(Map<String, dynamic> json) => SahSession(
    host: json['host'] as String,
    contextId: json['contextId'] as String,
    cookie: json['cookie'] as String,
  );
  Map<String, dynamic> toJson() => {
    'host': host,
    'contextId': contextId,
    'cookie': cookie,
  };

  static File defaultFile() {
    final home = Platform.environment['HOME'] ?? '.';
    return File('$home/.config/sah/session.json');
  }

  static SahSession? load([File? file]) {
    final f = file ?? defaultFile();
    if (!f.existsSync()) {
      return null;
    }
    final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return SahSession.fromJson(map);
  }

  void save([File? file]) {
    final f = file ?? defaultFile();
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n',
    );
  }

  static void clear([File? file]) {
    final f = file ?? defaultFile();
    if (f.existsSync()) {
      f.deleteSync();
    }
  }
}
