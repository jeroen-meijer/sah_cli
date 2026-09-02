import 'package:sah/src/style.dart';

/// One column in a CLI table / JSON projection.
///
/// [id] is both the table header and the `--fields` / `--sort-by` name.
///
/// [priority] controls narrow-terminal fit: **higher** values are truncated
/// and dropped first (less important). [flexible] columns may shrink below
/// their natural width; fixed columns keep natural width until dropped.
class const SahTableColumn({
  required final String id,
  required final Object? Function(Map<String, dynamic> row) value,
  final String Function(Object? value, SahStyle style)? format,

  /// Higher = less important (truncate / drop sooner). Default 50.
  final int priority = 50,

  /// When false, content is not shrunk (only the whole column may be dropped).
  final bool flexible = true,
});

/// One `--sort-by` key. Prefix the column id with `-` for descending.
class const SahSortKey({
  required final SahTableColumn column,
  final bool descending = false,
});

/// Result of fitting columns to a terminal width.
class const TableFit({
  required final List<SahTableColumn> columns,
  required final List<int> contentWidths,
});

/// Strip CSI color codes for width measurement.
final _ansiEscape = RegExp(r'\u001b\[[\d;]*m');

/// Visible column width (ANSI ignored).
int visibleWidth(String text) => text.replaceAll(_ansiEscape, '').length;

/// Truncate to [maxWidth] visible chars, appending `…` when clipped.
///
/// Keeps ANSI codes when the visible width already fits.
String truncateVisible(String text, int maxWidth) {
  if (maxWidth <= 0) {
    return '';
  }
  if (visibleWidth(text) <= maxWidth) {
    return text;
  }
  final plain = text.replaceAll(_ansiEscape, '');
  if (maxWidth == 1) {
    return '…';
  }
  return '${plain.substring(0, maxWidth - 1)}…';
}

/// Fit [columns] into [terminalWidth] by shrinking then dropping.
///
/// [cellText] is row-major formatted (or plain) cell strings used for natural
/// widths. Gap is the visible space between columns; [paddingPerColumn] matches
/// cli_table `paddingRight` (and left) included in the line budget.
TableFit fitTableToWidth({
  required List<SahTableColumn> columns,
  required List<List<String>> cellText,
  required int terminalWidth,
  int gap = 2,
  int paddingPerColumn = 1,
  int minFlexibleWidth = 3,
}) {
  if (columns.isEmpty) {
    return const TableFit(columns: [], contentWidths: []);
  }

  var cols = List<SahTableColumn>.of(columns);
  var widths = _naturalContentWidths(cols, cellText);

  int lineWidth() {
    if (widths.isEmpty) {
      return 0;
    }
    final content = widths.fold<int>(0, (a, b) => a + b);
    return content +
        widths.length * paddingPerColumn +
        (widths.length - 1) * gap;
  }

  while (lineWidth() > terminalWidth && cols.isNotEmpty) {
    final shrinkIndex = _indexToShrink(cols, widths, minFlexibleWidth);
    if (shrinkIndex != null) {
      widths[shrinkIndex]--;
      continue;
    }
    if (cols.length == 1) {
      widths[0] = _maxContentForSingleColumn(
        terminalWidth,
        paddingPerColumn,
        minFlexibleWidth,
      );
      break;
    }
    final dropIndex = _indexToDrop(cols);
    cols = [
      for (var i = 0; i < cols.length; i++)
        if (i != dropIndex) cols[i],
    ];
    widths = [
      for (var i = 0; i < widths.length; i++)
        if (i != dropIndex) widths[i],
    ];
  }

  return TableFit(columns: cols, contentWidths: widths);
}

List<int> _naturalContentWidths(
  List<SahTableColumn> columns,
  List<List<String>> cellText,
) {
  final widths = [for (final c in columns) visibleWidth(c.id)];
  for (final row in cellText) {
    for (var i = 0; i < columns.length && i < row.length; i++) {
      final w = visibleWidth(row[i]);
      if (w > widths[i]) {
        widths[i] = w;
      }
    }
  }
  return widths;
}

/// Highest [SahTableColumn.priority] among flexible columns above min width.
int? _indexToShrink(
  List<SahTableColumn> columns,
  List<int> widths,
  int minFlexibleWidth,
) {
  int? best;
  for (var i = 0; i < columns.length; i++) {
    final col = columns[i];
    if (!col.flexible || widths[i] <= minFlexibleWidth) {
      continue;
    }
    if (best == null ||
        col.priority > columns[best].priority ||
        (col.priority == columns[best].priority && i > best)) {
      best = i;
    }
  }
  return best;
}

/// Highest priority column (least important) to remove.
int _indexToDrop(List<SahTableColumn> columns) {
  var best = 0;
  for (var i = 1; i < columns.length; i++) {
    if (columns[i].priority > columns[best].priority ||
        (columns[i].priority == columns[best].priority && i > best)) {
      best = i;
    }
  }
  return best;
}

int _maxContentForSingleColumn(
  int terminalWidth,
  int paddingPerColumn,
  int minFlexibleWidth,
) {
  final available = terminalWidth - paddingPerColumn;
  if (available < minFlexibleWidth) {
    return available.clamp(1, minFlexibleWidth);
  }
  return available;
}

/// `--fields` / `--sort-by` resolution against a column catalog.
extension SahTableColumnListExtensions on List<SahTableColumn> {
  Map<String, SahTableColumn> get byId => {for (final c in this) c.id: c};

  String get idList => map((c) => c.id).join(', ');

  /// Resolve [fields]; order follows [fields] when set.
  ///
  /// Throws [FormatException] for unknown or empty selections.
  List<SahTableColumn> selectFields(List<String>? fields) {
    if (fields == null) {
      return this;
    }
    if (fields.isEmpty) {
      throw const FormatException('--fields must include at least one column');
    }
    final lookup = byId;
    return [
      for (final id in fields)
        lookup[id] ??
            (throw FormatException(
              'Unknown field "$id". Valid: $idList',
            )),
    ];
  }

  /// Parse [sortBy] tokens (`Name`, `-FirstSeen`). Empty input → empty list.
  List<SahSortKey> sortKeys(List<String> sortBy) {
    if (sortBy.isEmpty) {
      return const [];
    }
    final lookup = byId;
    return [
      for (final token in sortBy) _parseSortKey(token, lookup),
    ];
  }

  SahSortKey _parseSortKey(
    String token,
    Map<String, SahTableColumn> lookup,
  ) {
    final descending = token.startsWith('-');
    final id = descending ? token.substring(1) : token;
    if (id.isEmpty) {
      throw const FormatException(
        'Invalid sort-by "-": expected -<Column> (e.g. -FirstSeen)',
      );
    }
    final column = lookup[id];
    if (column == null) {
      throw FormatException(
        'Unknown sort-by "$token". Valid: $idList '
        '(prefix - for descending)',
      );
    }
    return SahSortKey(column: column, descending: descending);
  }
}

/// Row sort / JSON projection for SoftAtHome table commands.
extension SahTableRowListExtensions on List<Map<String, dynamic>> {
  /// Stable multi-key sort using raw [SahTableColumn.value]s.
  List<Map<String, dynamic>> sortedByColumns(List<SahSortKey> keys) {
    if (keys.isEmpty || length < 2) {
      return this;
    }
    return [
      ...this,
    ]..sort((a, b) {
      for (final key in keys) {
        final cmp = compareTableValues(
          key.column.value(a),
          key.column.value(b),
        );
        if (cmp != 0) {
          return key.descending ? -cmp : cmp;
        }
      }
      return 0;
    });
  }

  /// Project rows to maps keyed by column [SahTableColumn.id].
  List<Map<String, Object?>> projectColumns(List<SahTableColumn> columns) => [
    for (final row in this)
      {for (final col in columns) col.id: col.value(row)},
  ];
}

/// Nulls last; bool/num/DateTime/ISO strings; else case-insensitive text.
int compareTableValues(Object? a, Object? b) {
  if (identical(a, b)) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  if (a is bool && b is bool) {
    return a == b ? 0 : (a ? 1 : -1);
  }
  if (a is num && b is num) {
    return a.compareTo(b);
  }
  if (a is DateTime && b is DateTime) {
    return a.compareTo(b);
  }
  final aTime = _asDateTime(a);
  final bTime = _asDateTime(b);
  if (aTime != null && bTime != null) {
    return aTime.compareTo(bTime);
  }
  return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
}

DateTime? _asDateTime(Object value) {
  if (value is! String || value.isEmpty || value.startsWith('0001-01-01')) {
    return null;
  }
  return DateTime.tryParse(value);
}
