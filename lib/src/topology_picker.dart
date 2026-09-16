import 'dart:async';
import 'dart:io';

import 'package:sah/src/style.dart';
import 'package:sah/src/topology_tree.dart';

/// Interactive topology device picker (inspired by in_phase crawl redraw +
/// curate list select: ↑/↓, Enter, Esc; ANSI in-place redraw, no TUI package).
///
/// Returns the selected topology node, or `null` if cancelled / no candidates.
/// Ctrl+C restores the terminal and exits with code 130 (like a normal CLI).
Future<Map<String, dynamic>?> pickTopologyDevice({
  required Object? status,
  required SahStyle style,
  IOSink? sink,
  Stream<List<int>>? input,
}) async {
  final out = sink ?? stdout;
  final lines = flattenTopology(status);
  final selectable = [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].selectable) i,
  ];
  if (selectable.isEmpty) {
    out.writeln(
      style.muted('No reservable devices in topology (need MAC + IPv4).'),
    );
    return null;
  }

  if (!(out is Stdout && out.hasTerminal) || !stdin.hasTerminal) {
    out.writeln(
      '${style.errorLabel()} interactive select needs a TTY\n'
      '  ${style.tipLabel()} use `sah dhcp reserve <query>` instead',
    );
    return null;
  }

  // Raw mode before subscribing to stdin.
  final prevEcho = stdin.echoMode;
  final prevLine = stdin.lineMode;
  var restored = false;

  void restoreTerminal() {
    if (restored) {
      return;
    }
    restored = true;
    try {
      out.write('\x1b[?25h');
    } on Object {
      // ignore
    }
    try {
      stdin
        ..echoMode = prevEcho
        ..lineMode = prevLine;
    } on StdinException {
      // ignore
    }
  }

  stdin
    ..echoMode = false
    ..lineMode = false;
  out.write('\x1b[?25l');

  final stdinStream = input ?? stdin;
  final bytes = StreamIterator(stdinStream.expand((chunk) => chunk));

  // Ctrl+C: Dart keeps ISIG on when only line/echo mode change, so the TTY
  // delivers SIGINT (not byte 0x03). Watching it disables the default fatal
  // handler — restore the TTY and exit(130) like a normal CLI. Soft cancel
  // (Esc/q) returns null instead.
  final sigSub = ProcessSignal.sigint.watch().listen((_) {
    restoreTerminal();
    exit(130);
  });

  var sel = 0;
  var drawn = 0;
  var firstDraw = true;

  try {
    while (true) {
      drawn = _draw(
        out,
        style,
        lines,
        selectable,
        sel,
        erasePrevious: !firstDraw ? drawn : 0,
      );
      firstDraw = false;

      final key = await _readKey(bytes);
      switch (key) {
        case _Key.up:
          sel = (sel - 1 + selectable.length) % selectable.length;
        case _Key.down:
          sel = (sel + 1) % selectable.length;
        case _Key.confirm:
          return lines[selectable[sel]].node;
        case _Key.cancel:
        case _Key.eof:
          return null;
        case _Key.ignore:
          break;
      }
    }
  } finally {
    restoreTerminal();
    try {
      await sigSub.cancel().timeout(const Duration(milliseconds: 200));
    } on Object {
      // ignore
    }
    try {
      await bytes.cancel().timeout(const Duration(milliseconds: 200));
    } on Object {
      // ignore
    }
  }
}

enum _Key { up, down, confirm, cancel, eof, ignore }

Future<_Key> _readKey(StreamIterator<int> bytes) async {
  final first = await _next(bytes);
  if (first == null) {
    return _Key.eof;
  }
  // Ctrl-C / Ctrl-D as bytes (only if the TTY has ISIG off).
  if (first == 3 || first == 4) {
    return _Key.cancel;
  }
  if (first == 13 || first == 10) {
    return _Key.confirm;
  }
  if (first == 113 || first == 81) {
    // q / Q
    return _Key.cancel;
  }
  if (first == 106) {
    // j
    return _Key.down;
  }
  if (first == 107) {
    // k
    return _Key.up;
  }
  if (first != 27) {
    return _Key.ignore;
  }

  // ESC or CSI sequence (arrows). Bare Esc: short timeout.
  final second = await _next(
    bytes,
  ).timeout(const Duration(milliseconds: 50), onTimeout: () => null);
  if (second == null) {
    return _Key.cancel;
  }
  if (second != 91) {
    // not '['
    return _Key.cancel;
  }
  final third = await _next(bytes);
  if (third == 65) {
    return _Key.up;
  }
  if (third == 66) {
    return _Key.down;
  }
  return _Key.ignore;
}

Future<int?> _next(StreamIterator<int> bytes) async {
  if (!await bytes.moveNext()) {
    return null;
  }
  return bytes.current;
}

int _draw(
  IOSink out,
  SahStyle style,
  List<TopologyLine> lines,
  List<int> selectable,
  int sel, {
  required int erasePrevious,
}) {
  if (erasePrevious > 0) {
    out
      ..write('\r')
      ..write('\x1b[${erasePrevious}A')
      ..write('\x1b[0J');
  }

  final header = style.muted(
    'Select a device to reserve (↑/↓ or j/k, Enter, Esc)',
  );
  out.writeln(header);

  final selectedLine = selectable[sel];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final selected = i == selectedLine;
    final branch = style.branch(line.branchPrefix);
    final label = topologyLabel(
      line.node,
      style,
      emphasize: selected,
    );
    final cursor = selected
        ? (style.enabled ? style.ip('❯') : '>')
        : ' ';
    out
      ..write('\x1b[2K')
      ..writeln('$branch$cursor $label');
  }

  final hint = style.muted(
    '↑/↓ select · Enter lock current IP · Esc/q/Ctrl+C cancel',
  );
  out
    ..write('\x1b[2K')
    ..writeln(hint);

  return 1 + lines.length + 1;
}
