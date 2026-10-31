part of 'values.dart';

/// The 14 color spaces defined by the DTCG Color module (rev 2025.10).
enum ColorSpace {
  srgb('srgb'),
  srgbLinear('srgb-linear'),
  hsl('hsl'),
  hwb('hwb'),
  lab('lab'),
  lch('lch'),
  oklab('oklab'),
  oklch('oklch'),
  displayP3('display-p3'),
  a98Rgb('a98-rgb'),
  prophotoRgb('prophoto-rgb'),
  rec2020('rec2020'),
  xyzD65('xyz-d65'),
  xyzD50('xyz-d50');

  const ColorSpace(this.wireName);

  /// The exact string that appears in `"colorSpace"`.
  final String wireName;

  /// The index of the hue component for this space (0 for HSL/HWB, 2 for
  /// LCH/OKLCH), or `null` for spaces that don't have one.
  int? get hueComponentIndex => switch (this) {
    ColorSpace.hsl || ColorSpace.hwb => 0,
    ColorSpace.lch || ColorSpace.oklch => 2,
    _ => null,
  };

  static ColorSpace? byWireName(String name) =>
      _enumByWire(values, (s) => s.wireName, name);
}

/// A single color component.
///
/// Either a numeric value or the literal string `"none"` (§Color-module),
/// which is semantically distinct from `0` for interpolation purposes.
sealed class ColorComponent {
  const ColorComponent();

  Object toJson();
}

final RegExp _hexPattern = RegExp(r'^#[0-9a-fA-F]{6}$');

/// A numeric color component.
final class ComponentNumber extends ColorComponent {
  const ComponentNumber(this.value);

  final num value;

  @override
  Object toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComponentNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

/// The literal `"none"` component.
final class ComponentNone extends ColorComponent {
  const ComponentNone._();

  /// The singleton `"none"` component.
  static const ColorComponent none = ComponentNone._();

  @override
  Object toJson() => 'none';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ComponentNone;

  @override
  int get hashCode => 0x6E6F6E65;

  @override
  String toString() => 'none';
}

/// A `color` token value.
final class ColorValue extends TokenValue {
  const ColorValue({
    required this.colorSpace,
    required this.components,
    this.alpha,
    this.hex,
  });

  final ColorSpace colorSpace;
  final List<ColorComponent> components;
  final num? alpha;
  final String? hex;

  @override
  Object toJson() {
    final result = <String, Object?>{
      'colorSpace': colorSpace.wireName,
      'components': components.map((c) => c.toJson()).toList(growable: false),
    };
    if (alpha != null) result['alpha'] = alpha;
    if (hex != null) result['hex'] = hex;
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorValue &&
          other.colorSpace == colorSpace &&
          other.alpha == alpha &&
          other.hex == hex &&
          _deepEquality.equals(other.components, components);

  @override
  int get hashCode =>
      Object.hash(colorSpace, _deepEquality.hash(components), alpha, hex);

  @override
  String toString() =>
      'ColorValue(${colorSpace.wireName}, $components'
      '${alpha == null ? '' : ', alpha=$alpha'}'
      '${hex == null ? '' : ', hex=$hex'})';

  /// Parses a `$value` as a [ColorValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'color value must be a JSON object',
      );
      return null;
    }

    final space = _requireColorSpace(raw, errors);
    if (space == null) return null;

    final components = _parseColorComponents(raw, space, errors);
    if (components == null) return null;

    return ColorValue(
      colorSpace: space,
      components: List<ColorComponent>.unmodifiable(components),
      alpha: _parseOptionalAlpha(raw, errors),
      hex: _parseOptionalHex(raw, errors),
    );
  }

  static ColorSpace? _requireColorSpace(
    Map<Object?, Object?> raw,
    ErrorCollector errors,
  ) {
    final rawSpace = raw['colorSpace'];
    if (rawSpace is! String) {
      errors.error(
        IssueCode.invalidColorSpace,
        'color value is missing "colorSpace" or it is not a string',
      );
      return null;
    }
    final space = ColorSpace.byWireName(rawSpace);
    if (space == null) {
      errors.error(
        IssueCode.invalidColorSpace,
        'unknown colorSpace "$rawSpace"',
      );
      return null;
    }
    return space;
  }

  static List<ColorComponent>? _parseColorComponents(
    Map<Object?, Object?> raw,
    ColorSpace space,
    ErrorCollector errors,
  ) {
    final rawComponents = raw['components'];
    if (rawComponents is! List) {
      errors.error(
        IssueCode.valueWrongShape,
        'color value is missing "components" or it is not an array',
      );
      return null;
    }
    if (rawComponents.length != 3) {
      errors.error(
        IssueCode.wrongComponentCount,
        'colorSpace "${space.wireName}" expects 3 components, '
        'got ${rawComponents.length}',
      );
      return null;
    }
    final hueIndex = space.hueComponentIndex;
    return errors.withSegment('components', () {
      return _parseIndexedEntries<ColorComponent>(
        rawComponents,
        (entry, i) => _parseComponent(entry, i, hueIndex, errors),
        errors,
      );
    });
  }

  static ColorComponent? _parseComponent(
    Object? raw,
    int index,
    int? hueIndex,
    ErrorCollector errors,
  ) {
    if (raw is num) {
      if (index == hueIndex && raw == 360) {
        errors.error(
          IssueCode.hueOutOfRange,
          'hue 360 MUST NOT be used (use 0 instead)',
        );
      }
      return ComponentNumber(raw);
    }
    if (raw == 'none') return ComponentNone.none;
    errors.error(
      IssueCode.invalidColorComponent,
      'color component must be a number or the string "none"',
    );
    return null;
  }

  static num? _parseOptionalAlpha(
    Map<Object?, Object?> raw,
    ErrorCollector errors,
  ) {
    if (!raw.containsKey('alpha')) return null;
    final rawAlpha = raw['alpha'];
    if (rawAlpha is! num) {
      errors.errorAt(
        'alpha',
        IssueCode.alphaOutOfRange,
        'alpha must be a number',
      );
      return null;
    }
    if (rawAlpha < 0 || rawAlpha > 1) {
      errors.errorAt(
        'alpha',
        IssueCode.alphaOutOfRange,
        'alpha must be in [0, 1], got $rawAlpha',
      );
      return null;
    }
    return rawAlpha;
  }

  static String? _parseOptionalHex(
    Map<Object?, Object?> raw,
    ErrorCollector errors,
  ) {
    if (!raw.containsKey('hex')) return null;
    final rawHex = raw['hex'];
    if (rawHex is String && _hexPattern.hasMatch(rawHex)) return rawHex;
    errors.errorAt(
      'hex',
      IssueCode.invalidColorHex,
      'hex must be a 6-digit CSS hex string like "#336699"',
    );
    return null;
  }
}
