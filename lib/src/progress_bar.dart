import 'dart:async';
import 'dart:io';

/// Progress on stderr: `[=====>     ] 42%`
///
/// Pass `enabled: false` to skip drawing.
class ProgressBar({
  required final int total,
  final int width = 40,
  final String prefix = '',
  final bool enabled = true,
  IOSink? sink,
}) {
  final IOSink _sink = sink ?? stderr;

  var _current = 0;
  var _queue = Future<void>.value();

  void update(int current) {
    _current = current.clamp(0, total);
    if (!enabled) {
      return;
    }
    _queue = _queue.then((_) => _draw()).catchError((_) {});
  }

  Future<void> finish() async {
    if (!enabled) {
      return;
    }
    _current = total;
    await _queue;
    try {
      _sink
        ..write('\r${_line()}')
        ..writeln();
      await _flush();
    } catch (_) {
      // stderr can be busy if a flush is still running; skip
    }
  }

  /// Newline after a partial bar (failed transfer).
  Future<void> fail() async {
    if (!enabled) {
      return;
    }
    await _queue;
    try {
      _sink.writeln();
      await _flush();
    } catch (_) {
      // stderr can be busy if a flush is still running; skip
    }
  }

  String renderLine(int current) {
    final saved = _current;
    _current = current.clamp(0, total);
    final line = _line();
    _current = saved;
    return line;
  }

  String _line() {
    final pct = total > 0
        ? (_current * 100 / total).round().clamp(0, 100)
        : 100;
    final filled = total > 0
        ? (_current * width ~/ total).clamp(0, width)
        : width;

    final buffer = StringBuffer('[');
    for (var i = 0; i < width; i++) {
      if (i < filled - 1) {
        buffer.write('=');
      } else if (i == filled - 1 && filled < width) {
        buffer.write('>');
      } else if (i < filled) {
        buffer.write('=');
      } else {
        buffer.write(' ');
      }
    }
    buffer.write('] $pct%');
    return '$prefix$buffer';
  }

  Future<void> _draw() async {
    _sink.write('\r${_line()}');
    await _flush();
  }

  Future<void> _flush() async {
    if (_sink case final IOSink io) {
      await io.flush();
    }
  }
}
