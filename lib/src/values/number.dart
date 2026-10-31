part of 'values.dart';

/// A `number` token value (§8.7).
///
/// Any JSON number — no unit, no constraints.
final class NumberValue extends TokenValue {
  const NumberValue(this.value);

  final num value;

  @override
  Object toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NumberValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NumberValue($value)';

  /// Parses a `$value` as a [NumberValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! num) {
      errors.error(
        IssueCode.numberNotNumber,
        'number value must be a JSON number',
      );
      return null;
    }
    return NumberValue(raw);
  }
}
