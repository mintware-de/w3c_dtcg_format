part of 'values.dart';

/// The eight `strokeStyle` keywords (§9.3).
enum StrokeStyleKeyword {
  solid('solid'),
  dashed('dashed'),
  dotted('dotted'),
  double('double'),
  groove('groove'),
  ridge('ridge'),
  outset('outset'),
  inset('inset');

  const StrokeStyleKeyword(this.wireName);
  final String wireName;

  static StrokeStyleKeyword? byWireName(String name) =>
      _enumByWire(values, (k) => k.wireName, name);
}

/// The three `lineCap` keywords (§9.3).
enum LineCap {
  round('round'),
  butt('butt'),
  square('square');

  const LineCap(this.wireName);
  final String wireName;

  static LineCap? byWireName(String name) =>
      _enumByWire(values, (c) => c.wireName, name);
}

/// A `strokeStyle` token value (§9.3).
///
/// Either a keyword string, or a `{dashArray, lineCap}` object. Each entry
/// in [dashArray] is a [TokenValue] because the spec allows a dimension
/// value or a reference there.
sealed class StrokeStyleValue extends TokenValue {
  const StrokeStyleValue();

  const factory StrokeStyleValue.keyword(StrokeStyleKeyword keyword) =
      KeywordStrokeStyle;

  factory StrokeStyleValue.object({
    required List<TokenValue> dashArray,
    required LineCap lineCap,
  }) = ObjectStrokeStyle;

  /// Parses a `$value` as a [StrokeStyleValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is String) {
      final keyword = StrokeStyleKeyword.byWireName(raw);
      if (keyword == null) {
        errors.error(
          IssueCode.strokeStyleUnknownKeyword,
          'unknown strokeStyle keyword "$raw"',
        );
        return null;
      }
      return StrokeStyleValue.keyword(keyword);
    }
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'strokeStyle value must be a keyword string or a {dashArray, lineCap} object',
      );
      return null;
    }

    final rawDash = raw['dashArray'];
    final rawLineCap = raw['lineCap'];
    if (rawDash == null || rawLineCap == null) {
      errors.error(
        IssueCode.strokeStyleMissingField,
        'strokeStyle object requires "dashArray" and "lineCap"',
      );
      return null;
    }
    if (rawDash is! List) {
      errors.errorAt(
        'dashArray',
        IssueCode.valueWrongShape,
        'strokeStyle.dashArray must be an array',
      );
      return null;
    }
    final dashArray = errors.withSegment('dashArray', () {
      return _parseIndexedEntries<TokenValue>(rawDash, (entry, _) {
        final ref = tryParseReference(entry, errors);
        if (ref != null) return ref;
        return DimensionValue.parse(entry, errors);
      }, errors);
    });
    if (dashArray == null) return null;

    if (rawLineCap is! String) {
      errors.errorAt(
        'lineCap',
        IssueCode.strokeStyleBadLineCap,
        'strokeStyle.lineCap must be a string',
      );
      return null;
    }
    final lineCap = LineCap.byWireName(rawLineCap);
    if (lineCap == null) {
      errors.errorAt(
        'lineCap',
        IssueCode.strokeStyleBadLineCap,
        'strokeStyle.lineCap must be "round", "butt" or "square"',
      );
      return null;
    }

    return StrokeStyleValue.object(dashArray: dashArray, lineCap: lineCap);
  }
}

/// Keyword form of a [StrokeStyleValue].
final class KeywordStrokeStyle extends StrokeStyleValue {
  const KeywordStrokeStyle(this.keyword);
  final StrokeStyleKeyword keyword;

  @override
  Object toJson() => keyword.wireName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordStrokeStyle && other.keyword == keyword;

  @override
  int get hashCode => keyword.hashCode;

  @override
  String toString() => 'StrokeStyle(${keyword.wireName})';
}

/// Object form of a [StrokeStyleValue].
final class ObjectStrokeStyle extends StrokeStyleValue {
  ObjectStrokeStyle({
    required List<TokenValue> dashArray,
    required this.lineCap,
  }) : dashArray = List<TokenValue>.unmodifiable(dashArray);

  final List<TokenValue> dashArray;
  final LineCap lineCap;

  @override
  Object toJson() => <String, Object?>{
    'dashArray': dashArray.map((v) => v.toJson()).toList(growable: false),
    'lineCap': lineCap.wireName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectStrokeStyle &&
          other.lineCap == lineCap &&
          _deepEquality.equals(other.dashArray, dashArray);

  @override
  int get hashCode => Object.hash(_deepEquality.hash(dashArray), lineCap);

  @override
  String toString() =>
      'StrokeStyle(dashArray: $dashArray, lineCap: ${lineCap.wireName})';
}
