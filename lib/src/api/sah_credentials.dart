import 'dart:convert';
import 'dart:io';

/// Persisted SoftAtHome admin password for auto-relogin.
class const SahCredentials({
  required final String host,
  required final String password,
  final String username = 'admin',
}) {
  factory fromJson(Map<String, dynamic> json) => SahCredentials(
    host: json['host'] as String,
    password: json['password'] as String,
    username: json['username'] as String? ?? 'admin',
  );

  Map<String, dynamic> toJson() => {
    'host': host,
    'username': username,
    'password': password,
  };

  static File defaultFile() {
    final home = Platform.environment['HOME'] ?? '.';
    return File('$home/.config/sah/credentials.json');
  }

  static SahCredentials? load([File? file]) {
    final f = file ?? defaultFile();
    if (!f.existsSync()) {
      return null;
    }
    final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return SahCredentials.fromJson(map);
  }

  void save([File? file]) {
    final f = file ?? defaultFile();
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n',
    );
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['600', f.path]);
    }
  }

  static void clear([File? file]) {
    final f = file ?? defaultFile();
    if (f.existsSync()) {
      f.deleteSync();
    }
  }
}
