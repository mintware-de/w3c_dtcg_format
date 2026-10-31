part of 'values.dart';

/// A `cubicBezier` token value (§8.6).
///
/// Four control-point coordinates `[P1x, P1y, P2x, P2y]`. The x-values are
/// constrained to `[0, 1]`; the y-values may be any real number.
final class CubicBezierValue extends TokenValue {
  const CubicBezierValue(this.p1x, this.p1y, this.p2x, this.p2y);

  final num p1x;
  final num p1y;
  final num p2x;
  final num p2y;

  @override
  Object toJson() => <num>[p1x, p1y, p2x, p2y];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CubicBezierValue &&
          other.p1x == p1x &&
          other.p1y == p1y &&
          other.p2x == p2x &&
          other.p2y == p2y;

  @override
  int get hashCode => Object.hash(p1x, p1y, p2x, p2y);

  @override
  String toString() => 'CubicBezierValue($p1x, $p1y, $p2x, $p2y)';

  /// Parses a `$value` as a [CubicBezierValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! List) {
      errors.error(
        IssueCode.valueWrongShape,
        'cubicBezier value must be an array of four numbers',
      );
      return null;
    }
    if (raw.length != 4) {
      errors.error(
        IssueCode.cubicBezierBadArity,
        'cubicBezier must have exactly 4 entries, got ${raw.length}',
      );
      return null;
    }
    final numbers = _parseIndexedEntries<num>(raw, (entry, _) {
      if (entry is num) return entry;
      errors.error(
        IssueCode.cubicBezierNotNumbers,
        'cubicBezier entries must be numbers',
      );
      return null;
    }, errors);
    if (numbers == null) return null;

    _checkControlPointX(
      numbers[0],
      pointNumber: 1,
      segmentIndex: 0,
      errors: errors,
    );
    _checkControlPointX(
      numbers[2],
      pointNumber: 2,
      segmentIndex: 2,
      errors: errors,
    );
    return CubicBezierValue(numbers[0], numbers[1], numbers[2], numbers[3]);
  }

  static void _checkControlPointX(
    num x, {
    required int pointNumber,
    required int segmentIndex,
    required ErrorCollector errors,
  }) {
    if (x >= 0 && x <= 1) return;
    errors.errorAt(
      '$segmentIndex',
      IssueCode.cubicBezierXOutOfRange,
      'cubicBezier P${pointNumber}x must be in [0, 1], got $x',
    );
  }
}
