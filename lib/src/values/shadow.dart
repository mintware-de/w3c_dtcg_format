part of 'values.dart';

const _shadowFields = <String>{
  'color',
  'offsetX',
  'offsetY',
  'blur',
  'spread',
  'inset',
};

/// A single shadow sub-object inside a [ShadowValue].
///
/// Not a [TokenValue] on its own: callers always wrap it in a
/// [ShadowValue].
final class ShadowObject {
  const ShadowObject({
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.blur,
    required this.spread,
    this.inset = false,
  });

  final TokenValue color;
  final TokenValue offsetX;
  final TokenValue offsetY;
  final TokenValue blur;
  final TokenValue spread;
  final bool inset;

  Object toJson() => <String, Object?>{
    'color': color.toJson(),
    'offsetX': offsetX.toJson(),
    'offsetY': offsetY.toJson(),
    'blur': blur.toJson(),
    'spread': spread.toJson(),
    if (inset) 'inset': true,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShadowObject &&
          other.color == color &&
          other.offsetX == offsetX &&
          other.offsetY == offsetY &&
          other.blur == blur &&
          other.spread == spread &&
          other.inset == inset;

  @override
  int get hashCode => Object.hash(color, offsetX, offsetY, blur, spread, inset);

  @override
  String toString() =>
      'ShadowObject(color=$color, offset=($offsetX, $offsetY), '
      'blur=$blur, spread=$spread, inset=$inset)';
}

/// A `shadow` token value (§9.6).
///
/// The spec allows either a single shadow object or an array that may
/// contain shadow objects AND references to other shadow tokens. The
/// representation preserves that distinction so round-trip serialization
/// writes the original form back.
sealed class ShadowValue extends TokenValue {
  const ShadowValue();

  /// Wraps a single shadow object.
  const factory ShadowValue.single(ShadowObject shadow) = SingleShadow;

  /// Wraps a list where each element is either a shadow object (as a
  /// [SingleShadow] [TokenValue]) or an [AliasValue]/[RefValue].
  factory ShadowValue.list(List<TokenValue> entries) = ListShadow;

  /// Parses a `$value` as a [ShadowValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is Map) {
      final object = _parseShadowObject(raw, errors);
      if (object == null) return null;
      return ShadowValue.single(object);
    }
    if (raw is List) {
      final entries = _parseIndexedEntries<TokenValue>(raw, (entry, _) {
        final ref = tryParseReference(entry, errors);
        if (ref != null) return ref;
        final object = _parseShadowObject(entry, errors);
        if (object == null) return null;
        return _wrapShadowAsTokenValue(object);
      }, errors);
      if (entries == null) return null;
      return ShadowValue.list(entries);
    }
    errors.error(
      IssueCode.valueWrongShape,
      'shadow value must be a shadow object or an array of them',
    );
    return null;
  }

  static ShadowObject? _parseShadowObject(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'shadow entry must be a JSON object',
      );
      return null;
    }
    _warnExtraFields(raw, _shadowFields, errors);

    final color = _parseCompositeField(raw, 'color', ColorValue.parse, errors);
    final offsetX = _parseCompositeField(
      raw,
      'offsetX',
      DimensionValue.parse,
      errors,
    );
    final offsetY = _parseCompositeField(
      raw,
      'offsetY',
      DimensionValue.parse,
      errors,
    );
    final blur = _parseCompositeField(
      raw,
      'blur',
      DimensionValue.parse,
      errors,
    );
    final spread = _parseCompositeField(
      raw,
      'spread',
      DimensionValue.parse,
      errors,
    );
    bool inset = false;
    if (raw.containsKey('inset')) {
      final rawInset = raw['inset'];
      if (rawInset is! bool) {
        errors.errorAt(
          'inset',
          IssueCode.compositeFieldWrongType,
          'shadow.inset must be a boolean',
        );
        return null;
      }
      inset = rawInset;
    }
    if (color == null ||
        offsetX == null ||
        offsetY == null ||
        blur == null ||
        spread == null) {
      return null;
    }
    return ShadowObject(
      color: color,
      offsetX: offsetX,
      offsetY: offsetY,
      blur: blur,
      spread: spread,
      inset: inset,
    );
  }
}

/// Single-object form of a [ShadowValue].
final class SingleShadow extends ShadowValue {
  const SingleShadow(this.shadow);

  final ShadowObject shadow;

  @override
  Object toJson() => shadow.toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SingleShadow && other.shadow == shadow;

  @override
  int get hashCode => shadow.hashCode;

  @override
  String toString() => 'ShadowValue($shadow)';
}

/// Array form of a [ShadowValue].
final class ListShadow extends ShadowValue {
  ListShadow(List<TokenValue> entries)
    : entries = List<TokenValue>.unmodifiable(entries);

  final List<TokenValue> entries;

  @override
  Object toJson() => entries.map((e) => e.toJson()).toList(growable: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListShadow && _deepEquality.equals(other.entries, entries);

  @override
  int get hashCode => _deepEquality.hash(entries);

  @override
  String toString() => 'ShadowValue($entries)';
}

/// Wraps a bare shadow object as a [SingleShadow] [TokenValue] for use as
/// an element inside a list-form shadow value.
TokenValue _wrapShadowAsTokenValue(ShadowObject object) => SingleShadow(object);
