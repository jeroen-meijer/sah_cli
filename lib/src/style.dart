import 'dart:io';

import 'package:chalkdart/chalk.dart';

/// Terminal styling for human-readable CLI output.
class SahStyle({bool? color}) {
  final bool enabled =
      color ??
      (stdout.supportsAnsiEscapes && Platform.environment['NO_COLOR'] == null);

  static const yes = 'yes';
  static const no = 'no';
  static const up = 'up';
  static const down = 'down';

  late final Chalk _c = enabled ? chalk : Chalk.instance(level: 0);

  String title(String text) => enabled ? _c.bold.white(text) : text;

  String header(String text) => enabled ? _c.bold.cyan(text) : text;

  String key(String text) => enabled ? _c.dim(text) : text;

  String value(String text) => text;

  String name(String text) => enabled ? _c.bold(text) : text;

  String ip(String text) =>
      text.isEmpty ? text : (enabled ? _c.cyan(text) : text);

  String mac(String text) =>
      text.isEmpty ? text : (enabled ? _c.dim(text) : text);

  String muted(String text) => enabled ? _c.dim(text) : text;

  String branch(String text) => enabled ? _c.dim(text) : text;

  String ssid(String text) => enabled ? _c.yellow(text) : text;

  /// Color yes/no / up/down / Connected-style status tokens.
  String status(Object? raw) {
    final text = raw?.toString() ?? '';
    if (!enabled || text.isEmpty) {
      return text;
    }
    final lower = text.toLowerCase();
    if (lower == yes ||
        lower == up ||
        lower == 'true' ||
        lower == 'connected' ||
        lower == 'enabled') {
      return _c.green(text);
    }
    if (lower == no ||
        lower == down ||
        lower == 'false' ||
        lower == 'disconnected' ||
        lower == 'disabled') {
      return _c.red(text);
    }
    if (lower == 'error' || lower.contains('error')) {
      return _c.red(text);
    }
    return text;
  }

  /// Green [yes] / red [no], or empty when [value] is not a bool.
  String yesNo(Object? value) => switch (value) {
    true => status(yes),
    false => status(no),
    _ => '',
  };

  /// Yellow [yes] / dim [no] for DHCP reservation columns.
  String reserved(Object? value) => switch (value) {
    true => enabled ? _c.yellow(yes) : yes,
    false => enabled ? _c.dim(no) : no,
    _ => '',
  };

  /// Green [up] / red [down], or empty when [value] is not a bool.
  String upDown(Object? value) => switch (value) {
    true => status(up),
    false => status(down),
    _ => '',
  };

  /// SoftAtHome key/value field coloring for known keys.
  String fieldValue(String keyName, Object? raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) {
      return enabled ? _c.dim('—') : '';
    }
    switch (keyName) {
      case 'ConnectionState':
      case 'LinkState':
      case 'Status':
      case 'Enable':
      case 'Active':
        return status(text);
      case 'IPAddress':
      case 'IPv6Address':
      case 'RemoteGateway':
      case 'IPv6DelegatedPrefix':
        return ip(text);
      case 'MACAddress':
      case 'BaseMAC':
      case 'PhysAddress':
        return mac(text);
      case 'DNSServers':
        return enabled ? _c.cyan(text) : text;
      case 'LastConnectionError':
        return text == 'None' || text.isEmpty
            ? muted(text.isEmpty ? '—' : text)
            : (enabled ? _c.red(text) : text);
      default:
        return text;
    }
  }
}
