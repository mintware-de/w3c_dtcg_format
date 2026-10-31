part of 'values.dart';

/// Units a `duration` token accepts (§8.5).
enum DurationUnit {
  milliseconds('ms'),
  seconds('s');

  const DurationUnit(this.wireName);

  final String wireName;

  static DurationUnit? byWireName(String name) =>
      _enumByWire(values, (u) => u.wireName, name);
}

/// A `duration` token value.
final class DurationValue extends TokenValue {
  const DurationValue({required this.value, required this.unit});

  final num value;
  final DurationUnit unit;

  @override
  Object toJson() => <String, Object?>{'value': value, 'unit': unit.wireName};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DurationValue && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'DurationValue($value${unit.wireName})';

  /// Parses a `$value` as a [DurationValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'duration value must be a JSON object',
      );
      return null;
    }
    if (!raw.containsKey('value') || !raw.containsKey('unit')) {
      errors.error(
        IssueCode.durationMissingField,
        'duration value must have both "value" and "unit"',
      );
      return null;
    }
    final rawValue = raw['value'];
    if (rawValue is! num) {
      errors.errorAt(
        'value',
        IssueCode.durationValueNotNumber,
        'duration "value" must be a number',
      );
      return null;
    }
    final rawUnit = raw['unit'];
    if (rawUnit is! String) {
      errors.errorAt(
        'unit',
        IssueCode.invalidDurationUnit,
        'duration "unit" must be a string',
      );
      return null;
    }
    final unit = DurationUnit.byWireName(rawUnit);
    if (unit == null) {
      errors.errorAt(
        'unit',
        IssueCode.invalidDurationUnit,
        'duration "unit" must be "ms" or "s", got "$rawUnit"',
      );
      return null;
    }
    return DurationValue(value: rawValue, unit: unit);
  }
}
