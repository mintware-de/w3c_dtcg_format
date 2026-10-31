part of 'values.dart';

/// The two units `dimension` tokens accept in rev 2025.10.
enum DimensionUnit {
  px('px'),
  rem('rem');

  const DimensionUnit(this.wireName);
  final String wireName;

  static DimensionUnit? byWireName(String name) =>
      _enumByWire(values, (u) => u.wireName, name);
}

/// A `dimension` token value.
final class DimensionValue extends TokenValue {
  const DimensionValue({required this.value, required this.unit});

  final num value;
  final DimensionUnit unit;

  @override
  Object toJson() => <String, Object?>{'value': value, 'unit': unit.wireName};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DimensionValue && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'DimensionValue($value${unit.wireName})';

  /// Parses a `$value` as a [DimensionValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'dimension value must be a JSON object',
      );
      return null;
    }
    if (!raw.containsKey('value') || !raw.containsKey('unit')) {
      errors.error(
        IssueCode.dimensionMissingField,
        'dimension value must have both "value" and "unit"',
      );
      return null;
    }
    final rawValue = raw['value'];
    if (rawValue is! num) {
      errors.errorAt(
        'value',
        IssueCode.dimensionValueNotNumber,
        'dimension "value" must be a number',
      );
      return null;
    }
    final rawUnit = raw['unit'];
    if (rawUnit is! String) {
      errors.errorAt(
        'unit',
        IssueCode.invalidDimensionUnit,
        'dimension "unit" must be a string',
      );
      return null;
    }
    final unit = DimensionUnit.byWireName(rawUnit);
    if (unit == null) {
      errors.errorAt(
        'unit',
        IssueCode.invalidDimensionUnit,
        'dimension "unit" must be "px" or "rem", got "$rawUnit"',
      );
      return null;
    }
    return DimensionValue(value: rawValue, unit: unit);
  }
}
