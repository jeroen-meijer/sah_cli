import 'dart:io';

import 'package:sah/src/api/sah_exception.dart';
import 'package:sah/src/style.dart';

/// Write a cargo/clap-style diagnostic to [sink] (default stderr).
///
/// ```text
/// error: incorrect password
///   tip: check --password or SAH_PASSWORD, then run `sah login`
/// ```
void reportCliError(
  Object error, {
  SahStyle? style,
  StringSink? sink,
  String? tip,
}) {
  final s = style ?? SahStyle();
  final out = sink ?? stderr;
  final summary = formatCliError(error);
  final tipText = tip ?? (error is SahException ? error.tip : null);

  out.writeln('${s.errorLabel()} $summary');
  if (tipText != null && tipText.isNotEmpty) {
    out.writeln('  ${s.tipLabel()} $tipText');
  }
}
