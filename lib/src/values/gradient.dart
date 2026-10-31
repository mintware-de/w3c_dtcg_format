part of 'values.dart';

/// One stop in a [GradientValue] (§9.7).
final class GradientStop {
  const GradientStop({required this.color, required this.position});

  /// The stop colour: a [ColorValue] or a reference.
  final TokenValue color;

  /// The position in `[0, 1]`: a [NumberValue] or a reference.
  final TokenValue position;

  Object toJson() => <String, Object?>{
    'color': color.toJson(),
    'position': position.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradientStop &&
          other.color == color &&
          other.position == position;

  @override
  int get hashCode => Object.hash(color, position);

  @override
  String toString() => 'GradientStop($color @ $position)';

  static GradientStop? parse(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'gradient stop must be a JSON object',
      );
      return null;
    }
    _warnExtraFields(raw, _gradientStopFields, errors);

    final color = _parseCompositeField(raw, 'color', ColorValue.parse, errors);
    if (!raw.containsKey('position')) {
      errors.error(
        IssueCode.compositeMissingField,
        'gradient stop is missing required field "position"',
      );
      return null;
    }
    final rawPosition = raw['position'];
    final position = errors.withSegment('position', () {
      final ref = tryParseReference(rawPosition, errors);
      if (ref != null) return ref;
      if (rawPosition is! num) {
        errors.error(
          IssueCode.compositeFieldWrongType,
          'gradient stop "position" must be a number',
        );
        return null;
      }
      num clamped = rawPosition;
      if (rawPosition < 0 || rawPosition > 1) {
        errors.warning(
          IssueCode.gradientStopOutOfRange,
          'gradient stop position $rawPosition clamped into [0, 1]',
        );
        clamped = rawPosition < 0 ? 0 : 1;
      }
      return NumberValue(clamped);
    });
    if (color == null || position == null) return null;
    return GradientStop(color: color, position: position);
  }
}

const _gradientStopFields = <String>{'color', 'position'};

/// A `gradient` token value (§9.7).
///
/// The $value MUST be an array of gradient stops and/or references to
/// gradient-token values. Element references do NOT flatten.
final class GradientValue extends TokenValue {
  GradientValue(List<TokenValue> stops)
    : stops = List<TokenValue>.unmodifiable(stops);

  /// Each entry is a wrapped [GradientStop] or an [AliasValue]/[RefValue].
  final List<TokenValue> stops;

  @override
  Object toJson() => stops.map((s) => s.toJson()).toList(growable: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradientValue && _deepEquality.equals(other.stops, stops);

  @override
  int get hashCode => _deepEquality.hash(stops);

  @override
  String toString() => 'GradientValue($stops)';

  /// Parses a `$value` as a [GradientValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! List) {
      errors.error(
        IssueCode.gradientNotArray,
        'gradient value must be an array of stops',
      );
      return null;
    }
    final stops = _parseIndexedEntries<TokenValue>(raw, (entry, _) {
      final ref = tryParseReference(entry, errors);
      if (ref != null) return ref;
      final stop = GradientStop.parse(entry, errors);
      if (stop == null) return null;
      return GradientStopValue(stop);
    }, errors);
    if (stops == null) return null;
    return GradientValue(stops);
  }
}

/// A gradient stop wrapped as a [TokenValue] so it can participate in
/// the mixed `List<TokenValue>` carried by [GradientValue].
final class GradientStopValue extends TokenValue {
  const GradientStopValue(this.stop);

  final GradientStop stop;

  @override
  Object toJson() => stop.toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradientStopValue && other.stop == stop;

  @override
  int get hashCode => stop.hashCode;

  @override
  String toString() => 'GradientStopValue($stop)';
}
