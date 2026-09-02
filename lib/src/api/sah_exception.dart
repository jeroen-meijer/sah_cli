import 'dart:convert';

/// SoftAtHome API error.
class SahException(
  final String message, {
  final int? statusCode,
  final Object? body,
}) implements Exception {
  /// Login / createContext failed with HTTP 401 (wrong password on KPN).
  factory incorrectPassword({int? statusCode, Object? body}) => SahException(
    'incorrect password',
    statusCode: statusCode,
    body: body,
  );

  /// SoftAtHome error `196618` ("Object or parameter not found").
  bool get isObjectNotFound {
    final text = message.toLowerCase();
    if (text.contains('object or parameter not found') ||
        text.contains('196618')) {
      return true;
    }
    final map = body;
    if (map is Map && map['error'] == 196618) {
      return true;
    }
    if (map is Map) {
      final errors = map['errors'];
      if (errors is List) {
        for (final item in errors) {
          if (item is Map && item['error'] == 196618) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Session missing/expired or SoftAtHome auth-shaped failure (re-login eligible).
  bool get isAuthFailure {
    if (statusCode == 401 || statusCode == 403) {
      return true;
    }
    if (message == 'incorrect password' ||
        message.toLowerCase().contains('not authenticated')) {
      return true;
    }
    final description = _descriptionFromBodyOrMessage;
    if (description != null &&
        description.toLowerCase() == 'permission denied') {
      return true;
    }
    return false;
  }

  /// Short summary for stderr (no `error:` prefix; the reporter adds that).
  String get userMessage {
    if (message == 'incorrect password') {
      return 'incorrect password';
    }
    if (message == 'permission denied') {
      return 'permission denied';
    }

    if (statusCode == 401 &&
        (message.startsWith('HTTP ') ||
            message.toLowerCase().contains('login'))) {
      return 'incorrect password';
    }

    if (message.toLowerCase().contains('not authenticated')) {
      return 'not authenticated';
    }

    if (!message.startsWith('API error for ')) {
      if (message.startsWith('HTTP 401')) {
        return 'incorrect password';
      }
      return message;
    }

    final colon = message.indexOf(': ');
    if (colon < 0) {
      return message;
    }
    final call = message.substring('API error for '.length, colon);
    final payload = message.substring(colon + 2);

    if (isObjectNotFound) {
      if (call.contains('SpeedTest')) {
        return 'SpeedTest API not available on this gateway';
      }
      return '$call not available on this gateway';
    }

    final description = _errorDescription(payload);
    if (description != null &&
        description.toLowerCase() == 'permission denied') {
      return 'session expired or permission denied';
    }
    if (description != null && description.isNotEmpty) {
      return description;
    }

    return 'Call failed: $call';
  }

  /// Optional cargo/clap-style tip line (without `tip:` prefix).
  String? get tip {
    final summary = userMessage;
    return switch (summary) {
      'incorrect password' =>
        'check --password or SAH_PASSWORD, then run `sah login`',
      'session expired or permission denied' =>
        'run `sah login` (stores a password for auto-relogin)',
      'not authenticated' => 'run `sah login`',
      'permission denied' => null,
      _ => null,
    };
  }

  String? get _descriptionFromBodyOrMessage {
    final map = body;
    if (map is Map) {
      final direct = map['description']?.toString();
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }
      final errors = map['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map) {
          final d = first['description']?.toString();
          if (d != null && d.isNotEmpty) {
            return d;
          }
        }
      }
    }
    if (message.startsWith('API error for ')) {
      final colon = message.indexOf(': ');
      if (colon >= 0) {
        return _errorDescription(message.substring(colon + 2));
      }
    }
    return null;
  }

  static String? _errorDescription(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return decoded['description']?.toString();
      }
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) {
          return first['description']?.toString();
        }
      }
    } on FormatException {
      // Plain-text payload; ignore.
    }
    return null;
  }

  @override
  String toString() => 'SahException: $message';
}

/// User-facing text for any thrown object (stderr, tables).
String formatCliError(Object error) {
  if (error is SahException) {
    return error.userMessage;
  }
  final text = error.toString();
  const prefixes = ['Exception: ', 'Error: '];
  for (final prefix in prefixes) {
    final index = text.indexOf(prefix);
    if (index >= 0) {
      return text.substring(index + prefix.length);
    }
  }
  return text;
}
