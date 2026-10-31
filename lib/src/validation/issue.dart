/// A spec rule's severity when it is violated.
enum IssueSeverity {
  /// The document is invalid per the spec (a `MUST` was broken).
  error,

  /// The document is suspect but still parseable (a `SHOULD` was broken, or
  /// behaviour was auto-corrected per the spec, e.g. gradient-stop clamping).
  warning,
}

/// Stable identifiers for every rule the W3C DTCG spec (rev 2025.10) names.
///
/// Each code's dartdoc cites the §-reference in the spec it corresponds to.
enum IssueCode {
  // ---- Structural (§5) ----

  /// Document root was not a JSON object.
  nonObjectRoot,

  /// An object had both `$value` and child entries that look like tokens or
  /// groups (§5.1). The spec: tools MUST report this as an error.
  tokenAndChildrenConflict,

  /// Token or group name violates §5.1.1: begins with `$`, or contains any of
  /// `{`, `}`, `.`.
  invalidName,

  /// Two sibling names differ only by case. The spec says tools MAY warn
  /// because platform exports may collide (§5.1.1 note).
  caseInsensitiveNameCollision,

  /// A `$`-prefixed property that the spec does not define.
  unknownDollarProperty,

  // ---- Typing (§6) ----

  /// Token has no determinable `$type`: no own `$type`, no inherited group
  /// `$type`, and the alias chain (if any) does not yield one (§6.7.3).
  missingType,

  /// `$type` string is not one of the types this revision defines.
  unknownType,

  /// `$type` value is not a string.
  typeNotAString,

  // ---- Color (§8.1 / Color module) ----

  /// `colorSpace` is not one of the 14 defined spaces.
  invalidColorSpace,

  /// `components` has the wrong length for the declared `colorSpace`.
  wrongComponentCount,

  /// A `components` element is not a number and not the string `"none"`.
  invalidColorComponent,

  /// Hue component is `360` (the spec: hue 360 MUST NOT be used; 0 MAY be).
  hueOutOfRange,

  /// `alpha` is not in `[0, 1]`.
  alphaOutOfRange,

  /// `hex` fallback is not a valid 6-digit CSS hex string.
  invalidColorHex,

  /// A component outside the practical range for its space (warning only;
  /// the spec treats those ranges as advisory).
  colorComponentOutOfRange,

  // ---- Dimension (§8.2) ----

  /// `unit` is not `"px"` or `"rem"`.
  invalidDimensionUnit,

  /// `value` or `unit` is missing on a dimension object.
  dimensionMissingField,

  /// `value` is not a number.
  dimensionValueNotNumber,

  // ---- Font family (§8.3) ----

  /// `fontFamily` value is not a string and not an array of strings.
  invalidFontFamily,

  // ---- Font weight (§8.4) ----

  /// Numeric `fontWeight` outside `[1, 1000]`.
  fontWeightOutOfRange,

  /// `fontWeight` is a string that is not one of the defined keywords.
  unknownFontWeightKeyword,

  /// `fontWeight` is neither number nor string.
  invalidFontWeight,

  // ---- Duration (§8.5) ----

  /// `unit` is not `"ms"` or `"s"`.
  invalidDurationUnit,

  /// `value` or `unit` is missing on a duration object.
  durationMissingField,

  /// `value` is not a number.
  durationValueNotNumber,

  // ---- Cubic bezier (§8.6) ----

  /// Array length is not exactly 4.
  cubicBezierBadArity,

  /// `P1x` or `P2x` is outside `[0, 1]`.
  cubicBezierXOutOfRange,

  /// A control-point coordinate is not a number.
  cubicBezierNotNumbers,

  // ---- Number (§8.7) ----

  /// `$value` is not a number.
  numberNotNumber,

  // ---- Stroke style (§9.3) ----

  /// String form is not one of the eight defined keywords.
  strokeStyleUnknownKeyword,

  /// `lineCap` is not one of `round` / `butt` / `square`.
  strokeStyleBadLineCap,

  /// Stroke style object is missing a required field.
  strokeStyleMissingField,

  /// `dashArray` entry is not a dimension or a reference.
  strokeStyleBadDashEntry,

  // ---- Composite shared ----

  /// Composite missing a required sub-value.
  compositeMissingField,

  /// Composite has an extra sub-value the spec doesn't define (§9.2).
  compositeExtraField,

  /// A composite sub-value is of the wrong type.
  compositeFieldWrongType,

  /// `$value` had the wrong JSON shape for the declared type.
  valueWrongShape,

  // ---- Gradient (§9.7) ----

  /// `position` is outside `[0, 1]`. Spec clamps; emitted as a warning.
  gradientStopOutOfRange,

  /// Gradient `$value` is not an array.
  gradientNotArray,

  // ---- Aliases (§7) ----

  /// Brace reference target does not exist.
  aliasNotFound,

  /// `$ref` JSON Pointer does not resolve.
  refNotFound,

  /// Alias chain forms a cycle. Issue details carry every participant.
  aliasCycle,

  /// Brace reference syntax is malformed (not `{...}`).
  invalidAliasSyntax,

  /// `$ref` value is not a string.
  invalidRefSyntax,

  // ---- $extends (§5, §6.4) ----

  /// `$extends` target does not resolve.
  extendsNotFound,

  /// `$extends` resolves to a token, not a group.
  extendsTargetsToken,

  /// `$extends` chain forms a cycle.
  extendsCycle,

  /// `$extends` appeared on a token (group-only).
  extendsOnToken,
}

/// A validation issue produced during parsing or resolution.
///
/// [path] is an RFC 6901 JSON Pointer identifying the location in the input
/// document. [severity] distinguishes `MUST`-reject errors from `SHOULD`-tier
/// warnings. [details] is free-form metadata — e.g. the full cycle for a
/// cycle error — intended for tooling, not display.
final class ValidationIssue {
  const ValidationIssue({
    required this.path,
    required this.code,
    required this.severity,
    required this.message,
    this.details,
  });

  final String path;
  final IssueCode code;
  final IssueSeverity severity;
  final String message;
  final Object? details;

  @override
  String toString() =>
      '[${severity.name}] ${code.name} @ $path: $message'
      '${details == null ? '' : ' (details: $details)'}';
}
