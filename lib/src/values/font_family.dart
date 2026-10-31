part of 'values.dart';

/// A `fontFamily` token value.
///
/// The spec allows either a single family name or an array of names
/// forming a fallback stack. The in-memory representation always carries
/// a non-empty [families] list; [isStack] records which wire form was used,
/// so round-trip encoding preserves the original shape.
final class FontFamilyValue extends TokenValue {
  const FontFamilyValue._(this.families, this.isStack);

  /// Constructs the single-string form.
  FontFamilyValue.single(String family)
    : families = List<String>.unmodifiable([family]),
      isStack = false;

  /// Constructs the array form.
  factory FontFamilyValue.stack(List<String> families) =>
      FontFamilyValue._(List<String>.unmodifiable(families), true);

  /// The ordered family list (always at least one entry).
  final List<String> families;

  /// Whether the source form was an array.
  final bool isStack;

  @override
  Object toJson() {
    if (!isStack && families.length == 1) return families.first;
    return List<String>.from(families);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontFamilyValue &&
          other.isStack == isStack &&
          _deepEquality.equals(other.families, families);

  @override
  int get hashCode => Object.hash(isStack, _deepEquality.hash(families));

  @override
  String toString() => 'FontFamilyValue($families)';

  /// Parses a `$value` as a [FontFamilyValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is String) return FontFamilyValue.single(raw);
    if (raw is List) {
      if (raw.isEmpty) {
        errors.error(
          IssueCode.invalidFontFamily,
          'fontFamily array must not be empty',
        );
        return null;
      }
      final families = _parseIndexedEntries<String>(raw, (entry, _) {
        if (entry is String) return entry;
        errors.error(
          IssueCode.invalidFontFamily,
          'fontFamily array entries must be strings',
        );
        return null;
      }, errors);
      if (families == null) return null;
      return FontFamilyValue.stack(families);
    }
    errors.error(
      IssueCode.invalidFontFamily,
      'fontFamily must be a string or an array of strings',
    );
    return null;
  }
}
