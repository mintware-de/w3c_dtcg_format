part of 'values.dart';

const _typographyFields = <String>{
  'fontFamily',
  'fontSize',
  'fontWeight',
  'letterSpacing',
  'lineHeight',
};

/// A `typography` token value (§9.8).
final class TypographyValue extends TokenValue {
  const TypographyValue({
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
    required this.lineHeight,
  });

  /// A [FontFamilyValue] or a reference.
  final TokenValue fontFamily;

  /// A [DimensionValue] or a reference.
  final TokenValue fontSize;

  /// A [FontWeightValue] or a reference.
  final TokenValue fontWeight;

  /// A [DimensionValue] or a reference.
  final TokenValue letterSpacing;

  /// A [NumberValue] or a reference. The spec SHOULD-interprets it as a
  /// multiplier of [fontSize].
  final TokenValue lineHeight;

  @override
  Object toJson() => <String, Object?>{
    'fontFamily': fontFamily.toJson(),
    'fontSize': fontSize.toJson(),
    'fontWeight': fontWeight.toJson(),
    'letterSpacing': letterSpacing.toJson(),
    'lineHeight': lineHeight.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyValue &&
          other.fontFamily == fontFamily &&
          other.fontSize == fontSize &&
          other.fontWeight == fontWeight &&
          other.letterSpacing == letterSpacing &&
          other.lineHeight == lineHeight;

  @override
  int get hashCode =>
      Object.hash(fontFamily, fontSize, fontWeight, letterSpacing, lineHeight);

  @override
  String toString() =>
      'TypographyValue(fontFamily=$fontFamily, fontSize=$fontSize, '
      'fontWeight=$fontWeight, letterSpacing=$letterSpacing, '
      'lineHeight=$lineHeight)';

  /// Parses a `$value` as a [TypographyValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'typography value must be a JSON object',
      );
      return null;
    }
    _warnExtraFields(raw, _typographyFields, errors);

    final fontFamily = _parseCompositeField(
      raw,
      'fontFamily',
      FontFamilyValue.parse,
      errors,
    );
    final fontSize = _parseCompositeField(
      raw,
      'fontSize',
      DimensionValue.parse,
      errors,
    );
    final fontWeight = _parseCompositeField(
      raw,
      'fontWeight',
      FontWeightValue.parse,
      errors,
    );
    final letterSpacing = _parseCompositeField(
      raw,
      'letterSpacing',
      DimensionValue.parse,
      errors,
    );
    final lineHeight = _parseCompositeField(
      raw,
      'lineHeight',
      NumberValue.parse,
      errors,
    );
    if (fontFamily == null ||
        fontSize == null ||
        fontWeight == null ||
        letterSpacing == null ||
        lineHeight == null) {
      return null;
    }
    return TypographyValue(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
    );
  }
}
