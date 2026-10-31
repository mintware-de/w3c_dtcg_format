part of 'values.dart';

const _borderFields = <String>{'color', 'width', 'style'};

/// A `border` token value (§9.4).
///
/// Each field holds a [TokenValue] because the spec allows either a
/// literal value or an alias/`$ref` in every slot.
final class BorderValue extends TokenValue {
  const BorderValue({
    required this.color,
    required this.width,
    required this.style,
  });

  /// The border colour: a [ColorValue] or an [AliasValue]/[RefValue].
  final TokenValue color;

  /// The border width: a [DimensionValue] or an [AliasValue]/[RefValue].
  final TokenValue width;

  /// The stroke style: a [StrokeStyleValue] or an [AliasValue]/[RefValue].
  final TokenValue style;

  @override
  Object toJson() => <String, Object?>{
    'color': color.toJson(),
    'width': width.toJson(),
    'style': style.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorderValue &&
          other.color == color &&
          other.width == width &&
          other.style == style;

  @override
  int get hashCode => Object.hash(color, width, style);

  @override
  String toString() => 'BorderValue(color=$color, width=$width, style=$style)';

  /// Parses a `$value` as a [BorderValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'border value must be a JSON object',
      );
      return null;
    }
    _warnExtraFields(raw, _borderFields, errors);

    final color = _parseCompositeField(raw, 'color', ColorValue.parse, errors);
    final width = _parseCompositeField(
      raw,
      'width',
      DimensionValue.parse,
      errors,
    );
    final style = _parseCompositeField(
      raw,
      'style',
      StrokeStyleValue.parse,
      errors,
    );
    if (color == null || width == null || style == null) return null;
    return BorderValue(color: color, width: width, style: style);
  }
}

/// Parses one required sub-value of a composite.
///
/// First tries to interpret the raw sub-value as an alias/`$ref`; failing
/// that, delegates to the typed parser. Missing fields emit
/// [IssueCode.compositeMissingField] at the composite's own path.
TokenValue? _parseCompositeField(
  Map<Object?, Object?> raw,
  String field,
  TokenValue? Function(Object?, ErrorCollector) parser,
  ErrorCollector errors,
) {
  if (!raw.containsKey(field)) {
    errors.error(
      IssueCode.compositeMissingField,
      'composite is missing required field "$field"',
    );
    return null;
  }
  return errors.withSegment(field, () {
    final rawEntry = raw[field];
    final ref = tryParseReference(rawEntry, errors);
    if (ref != null) return ref;
    return parser(rawEntry, errors);
  });
}

void _warnExtraFields(
  Map<Object?, Object?> raw,
  Set<String> allowed,
  ErrorCollector errors,
) {
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String || allowed.contains(key)) continue;
    errors.warningAt(
      key,
      IssueCode.compositeExtraField,
      'composite has unexpected field "$key"',
    );
  }
}
