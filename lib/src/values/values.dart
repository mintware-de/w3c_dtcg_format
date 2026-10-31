/// The sealed [TokenValue] hierarchy and the per-type parsers.
///
/// All concrete value classes live in `part` files that share this
/// library. Importers should go through the public barrel
/// (`package:w3c_dtcg_format/w3c_dtcg_format.dart`) rather than reaching
/// into this file directly.
library;

import 'package:collection/collection.dart';

import '../validation/error_collector.dart';
import '../validation/issue.dart';

part 'alias.dart';
part 'border.dart';
part 'color.dart';
part 'cubic_bezier.dart';
part 'dimension.dart';
part 'duration.dart';
part 'font_family.dart';
part 'font_weight.dart';
part 'gradient.dart';
part 'number.dart';
part 'shadow.dart';
part 'stroke_style.dart';
part 'transition.dart';
part 'typography.dart';

/// The set of `$type` strings this revision of the spec defines.
///
/// Enum constant names deliberately match the wire form exactly so
/// [Enum.name] returns the correct string.
enum TokenType {
  color,
  dimension,
  fontFamily,
  fontWeight,
  duration,
  cubicBezier,
  number,
  strokeStyle,
  border,
  transition,
  shadow,
  gradient,
  typography;

  /// Resolves a `$type` wire string to a [TokenType], or `null` on unknown.
  static TokenType? byName(String name) =>
      _enumByWire(values, (t) => t.name, name);
}

/// Base of every parsed `$value`.
///
/// Subtypes are hand-sealed within this library. The sum-type nature of
/// several values (alias-vs-concrete, number-vs-keyword, object-vs-array)
/// makes a dispatched `fromJson` cleaner than any code-generated solution.
sealed class TokenValue {
  const TokenValue();

  /// Returns the JSON-serializable representation of this value, suitable
  /// for round-tripping back through `jsonEncode`.
  ///
  /// Alias values round-trip as their original brace or `$ref` form —
  /// resolution is a separate concern.
  Object toJson();
}

/// Parses [raw] as a token value of the declared [type].
///
/// When [type] is `null`, the caller has not been able to resolve a `$type`
/// for this token — the only shapes this function will accept are
/// references (brace alias or `$ref`), since those can inherit a type from
/// their target. Any concrete shape produces a [IssueCode.missingType]
/// error. When [type] is a known enum, the appropriate per-type parser is
/// dispatched; when it is a string the enum doesn't cover, the parser
/// emits [IssueCode.unknownType].
TokenValue? parseTokenValue(
  TokenType? type,
  Object? raw,
  ErrorCollector errors,
) {
  final reference = tryParseReference(raw, errors);
  if (reference != null) return reference;

  if (type == null) {
    errors.error(
      IssueCode.missingType,
      'token has no determinable \$type and its value is not an alias',
    );
    return null;
  }

  return switch (type) {
    TokenType.color => ColorValue.parse(raw, errors),
    TokenType.dimension => DimensionValue.parse(raw, errors),
    TokenType.fontFamily => FontFamilyValue.parse(raw, errors),
    TokenType.fontWeight => FontWeightValue.parse(raw, errors),
    TokenType.duration => DurationValue.parse(raw, errors),
    TokenType.cubicBezier => CubicBezierValue.parse(raw, errors),
    TokenType.number => NumberValue.parse(raw, errors),
    TokenType.strokeStyle => StrokeStyleValue.parse(raw, errors),
    TokenType.border => BorderValue.parse(raw, errors),
    TokenType.transition => TransitionValue.parse(raw, errors),
    TokenType.shadow => ShadowValue.parse(raw, errors),
    TokenType.gradient => GradientValue.parse(raw, errors),
    TokenType.typography => TypographyValue.parse(raw, errors),
  };
}

const DeepCollectionEquality _deepEquality = DeepCollectionEquality();

/// Walks [raw] indexed, parsing each entry under its own `$i` segment, and
/// bails on the first entry [parse] rejects (returning `null`).
///
/// Replaces the hand-rolled "for i, withSegment, add-or-return-null" loop
/// repeated across the value parsers.
List<T>? _parseIndexedEntries<T>(
  List<Object?> raw,
  T? Function(Object? entry, int index) parse,
  ErrorCollector errors,
) {
  final out = <T>[];
  for (var i = 0; i < raw.length; i++) {
    final parsed = errors.withSegment('$i', () => parse(raw[i], i));
    if (parsed == null) return null;
    out.add(parsed);
  }
  return out;
}

/// Returns the enum value whose `wire` string equals [name], or `null`.
///
/// Replaces the six near-identical `byWireName` statics across the value
/// enums.
E? _enumByWire<E extends Enum>(
  List<E> values,
  String Function(E) wire,
  String name,
) {
  for (final v in values) {
    if (wire(v) == name) return v;
  }
  return null;
}
