import 'dart:convert';

/// SoftAtHome API error.
class SahException(
  final String message, {
  final int? statusCode,
  final Object? body,
}) implements Exception {
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

  /// Text for stderr and error tables (no `SahException:` prefix).
  String get userMessage {
    if (!message.startsWith('API error for ')) {
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
    if (description != null && description.isNotEmpty) {
      return description;
    }

    return 'Call failed: $call';
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
