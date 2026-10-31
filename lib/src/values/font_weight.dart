part of 'values.dart';

/// Weight keywords defined in §8.4.
enum FontWeightKeyword {
  thin('thin', 100),
  hairline('hairline', 100),
  extraLight('extra-light', 200),
  ultraLight('ultra-light', 200),
  light('light', 300),
  normal('normal', 400),
  regular('regular', 400),
  book('book', 400),
  medium('medium', 500),
  semiBold('semi-bold', 600),
  demiBold('demi-bold', 600),
  bold('bold', 700),
  extraBold('extra-bold', 800),
  ultraBold('ultra-bold', 800),
  black('black', 900),
  heavy('heavy', 900),
  extraBlack('extra-black', 950),
  ultraBlack('ultra-black', 950);

  const FontWeightKeyword(this.wireName, this.numericWeight);

  final String wireName;
  final int numericWeight;

  static FontWeightKeyword? byWireName(String name) =>
      _enumByWire(values, (kw) => kw.wireName, name);
}

/// A `fontWeight` token value.
///
/// Either a numeric weight in `[1, 1000]` or one of the spec's keywords.
sealed class FontWeightValue extends TokenValue {
  const FontWeightValue();

  /// The numeric weight associated with this value.
  int get numericWeight;

  /// Constructs the numeric form.
  const factory FontWeightValue.numeric(int weight) = NumericFontWeight;

  /// Constructs the keyword form.
  const factory FontWeightValue.keyword(FontWeightKeyword keyword) =
      KeywordFontWeight;

  /// Parses a `$value` as a [FontWeightValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is num) {
      if (raw != raw.truncate() || raw < 1 || raw > 1000) {
        errors.error(
          IssueCode.fontWeightOutOfRange,
          'fontWeight must be an integer in [1, 1000], got $raw',
        );
        return null;
      }
      return FontWeightValue.numeric(raw.toInt());
    }
    if (raw is String) {
      final keyword = FontWeightKeyword.byWireName(raw);
      if (keyword == null) {
        errors.error(
          IssueCode.unknownFontWeightKeyword,
          'unknown fontWeight keyword "$raw"',
        );
        return null;
      }
      return FontWeightValue.keyword(keyword);
    }
    errors.error(
      IssueCode.invalidFontWeight,
      'fontWeight must be a number or a defined keyword string',
    );
    return null;
  }
}

/// Numeric form of a [FontWeightValue].
final class NumericFontWeight extends FontWeightValue {
  const NumericFontWeight(this.weight);

  final int weight;

  @override
  int get numericWeight => weight;

  @override
  Object toJson() => weight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NumericFontWeight && other.weight == weight;

  @override
  int get hashCode => weight.hashCode;

  @override
  String toString() => 'FontWeight($weight)';
}

/// Keyword form of a [FontWeightValue].
final class KeywordFontWeight extends FontWeightValue {
  const KeywordFontWeight(this.keyword);

  final FontWeightKeyword keyword;

  @override
  int get numericWeight => keyword.numericWeight;

  @override
  Object toJson() => keyword.wireName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordFontWeight && other.keyword == keyword;

  @override
  int get hashCode => keyword.hashCode;

  @override
  String toString() => 'FontWeight(${keyword.wireName})';
}
