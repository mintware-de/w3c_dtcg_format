import 'dart:convert';

import 'package:test/test.dart';
import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

/// Round-trips a single-token document whose root type is [type] and whose
/// `$value` is [valueJson]. Returns the parsed [TokenValue], failing the
/// test if parsing emits any issue.
TokenValue _parseValue(String type, Object valueJson) {
  final doc = <String, Object?>{
    't': <String, Object?>{r'$type': type, r'$value': valueJson},
  };
  final result = parseDocumentString(jsonEncode(doc));
  expect(result.issues, isEmpty, reason: result.issues.toString());
  final token = result.document!.root.children['t']! as Token;
  return token.value;
}

/// Parses [valueJson] under [type] and asserts the only issue produced is
/// of [code]. Returns the collected issues for additional assertions.
List<ValidationIssue> _parseValueExpectingError(
  String type,
  Object valueJson,
  IssueCode code,
) {
  final doc = <String, Object?>{
    't': <String, Object?>{r'$type': type, r'$value': valueJson},
  };
  final result = parseDocumentString(jsonEncode(doc));
  final errors = result.issues
      .where((i) => i.severity == IssueSeverity.error)
      .toList();
  expect(errors, isNotEmpty, reason: 'expected $code, got no errors');
  expect(errors.first.code, code);
  return result.issues;
}

void main() {
  group('color', () {
    test('srgb object with alpha and hex', () {
      final value = _parseValue('color', <String, Object?>{
        'colorSpace': 'srgb',
        'components': [1, 0, 0.5],
        'alpha': 0.75,
        'hex': '#ff0080',
      });
      final color = value as ColorValue;
      expect(color.colorSpace, ColorSpace.srgb);
      expect(color.components, [
        const ComponentNumber(1),
        const ComponentNumber(0),
        const ComponentNumber(0.5),
      ]);
      expect(color.alpha, 0.75);
      expect(color.hex, '#ff0080');
    });

    test('accepts "none" components', () {
      final value = _parseValue('color', <String, Object?>{
        'colorSpace': 'oklch',
        'components': [0.7, 'none', 180],
      }) as ColorValue;
      expect(value.components[1], ComponentNone.none);
    });

    test('rejects hue=360', () {
      _parseValueExpectingError('color', <String, Object?>{
        'colorSpace': 'hsl',
        'components': [360, 50, 50],
      }, IssueCode.hueOutOfRange);
    });

    test('rejects wrong component count', () {
      _parseValueExpectingError('color', <String, Object?>{
        'colorSpace': 'srgb',
        'components': [1, 0],
      }, IssueCode.wrongComponentCount);
    });

    test('rejects unknown colorSpace', () {
      _parseValueExpectingError('color', <String, Object?>{
        'colorSpace': 'cmyk',
        'components': [0, 0, 0, 1],
      }, IssueCode.invalidColorSpace);
    });

    test('rejects invalid hex', () {
      _parseValueExpectingError('color', <String, Object?>{
        'colorSpace': 'srgb',
        'components': [0, 0, 0],
        'hex': '#ABC',
      }, IssueCode.invalidColorHex);
    });

    test('rejects alpha out of range', () {
      _parseValueExpectingError('color', <String, Object?>{
        'colorSpace': 'srgb',
        'components': [0, 0, 0],
        'alpha': 1.5,
      }, IssueCode.alphaOutOfRange);
    });
  });

  group('dimension', () {
    test('px and rem', () {
      final px = _parseValue('dimension', <String, Object?>{
        'value': 16,
        'unit': 'px',
      }) as DimensionValue;
      final rem = _parseValue('dimension', <String, Object?>{
        'value': 1.5,
        'unit': 'rem',
      }) as DimensionValue;
      expect(px.unit, DimensionUnit.px);
      expect(px.value, 16);
      expect(rem.unit, DimensionUnit.rem);
      expect(rem.value, 1.5);
    });

    test('rejects % and em', () {
      for (final unit in const ['%', 'em', 'vh', 'vw']) {
        _parseValueExpectingError('dimension', <String, Object?>{
          'value': 1,
          'unit': unit,
        }, IssueCode.invalidDimensionUnit);
      }
    });

    test('rejects missing unit even when value is 0', () {
      _parseValueExpectingError('dimension', <String, Object?>{
        'value': 0,
      }, IssueCode.dimensionMissingField);
    });
  });

  group('fontFamily', () {
    test('single string', () {
      final value = _parseValue('fontFamily', 'Roboto') as FontFamilyValue;
      expect(value.families, ['Roboto']);
      expect(value.isStack, isFalse);
    });

    test('stack', () {
      final value = _parseValue('fontFamily', <String>[
        'Roboto',
        'sans-serif',
      ]) as FontFamilyValue;
      expect(value.families, ['Roboto', 'sans-serif']);
      expect(value.isStack, isTrue);
    });

    test('rejects numeric', () {
      _parseValueExpectingError('fontFamily', 42, IssueCode.invalidFontFamily);
    });
  });

  group('fontWeight', () {
    test('numeric', () {
      final value = _parseValue('fontWeight', 650) as FontWeightValue;
      expect(value, isA<NumericFontWeight>());
      expect(value.numericWeight, 650);
    });

    test('every keyword maps to the right weight', () {
      for (final kw in FontWeightKeyword.values) {
        final value = _parseValue('fontWeight', kw.wireName) as FontWeightValue;
        expect(value, isA<KeywordFontWeight>());
        expect(value.numericWeight, kw.numericWeight);
      }
    });

    test('rejects out of range', () {
      _parseValueExpectingError(
        'fontWeight',
        0,
        IssueCode.fontWeightOutOfRange,
      );
      _parseValueExpectingError(
        'fontWeight',
        1001,
        IssueCode.fontWeightOutOfRange,
      );
    });

    test('rejects unknown keyword', () {
      _parseValueExpectingError(
        'fontWeight',
        'super-bold',
        IssueCode.unknownFontWeightKeyword,
      );
    });
  });

  group('duration', () {
    test('ms and s', () {
      final ms = _parseValue('duration', <String, Object?>{
        'value': 250,
        'unit': 'ms',
      }) as DurationValue;
      final s = _parseValue('duration', <String, Object?>{
        'value': 0.25,
        'unit': 's',
      }) as DurationValue;
      expect(ms.unit, DurationUnit.milliseconds);
      expect(s.unit, DurationUnit.seconds);
    });

    test('rejects unknown unit', () {
      _parseValueExpectingError('duration', <String, Object?>{
        'value': 1,
        'unit': 'min',
      }, IssueCode.invalidDurationUnit);
    });
  });

  group('cubicBezier', () {
    test('valid', () {
      final value = _parseValue('cubicBezier', <num>[
        0.25,
        0.1,
        0.25,
        1,
      ]) as CubicBezierValue;
      expect(value.p1x, 0.25);
      expect(value.p2y, 1);
    });

    test('rejects x out of range', () {
      _parseValueExpectingError('cubicBezier', const <num>[
        -0.1,
        0,
        1.1,
        1,
      ], IssueCode.cubicBezierXOutOfRange);
    });

    test('rejects wrong arity', () {
      _parseValueExpectingError('cubicBezier', const <num>[
        0,
        0,
        1,
      ], IssueCode.cubicBezierBadArity);
    });
  });

  group('number', () {
    test('any number', () {
      final value = _parseValue('number', -3.14) as NumberValue;
      expect(value.value, -3.14);
    });

    test('rejects strings', () {
      _parseValueExpectingError('number', '3.14', IssueCode.numberNotNumber);
    });
  });

  group('strokeStyle', () {
    test('keyword form', () {
      final value = _parseValue('strokeStyle', 'dashed') as KeywordStrokeStyle;
      expect(value.keyword, StrokeStyleKeyword.dashed);
    });

    test('object form', () {
      final value = _parseValue('strokeStyle', <String, Object?>{
        'dashArray': [
          <String, Object?>{'value': 4, 'unit': 'px'},
          <String, Object?>{'value': 2, 'unit': 'px'},
        ],
        'lineCap': 'butt',
      }) as ObjectStrokeStyle;
      expect(value.lineCap, LineCap.butt);
      expect(value.dashArray, hasLength(2));
    });

    test('rejects unknown lineCap', () {
      _parseValueExpectingError('strokeStyle', <String, Object?>{
        'dashArray': const <Object?>[],
        'lineCap': 'triangle',
      }, IssueCode.strokeStyleBadLineCap);
    });
  });

  group('border', () {
    test('inline', () {
      final value = _parseValue('border', <String, Object?>{
        'color': <String, Object?>{
          'colorSpace': 'srgb',
          'components': [0, 0, 0],
        },
        'width': <String, Object?>{'value': 1, 'unit': 'px'},
        'style': 'solid',
      }) as BorderValue;
      expect(value.color, isA<ColorValue>());
      expect(value.width, isA<DimensionValue>());
      expect(value.style, isA<KeywordStrokeStyle>());
    });

    test('with aliased sub-fields', () {
      final value = _parseValue('border', <String, Object?>{
        'color': '{color.accent}',
        'width': '{sizes.border}',
        'style': 'solid',
      }) as BorderValue;
      expect(value.color, isA<AliasValue>());
      expect(value.width, isA<AliasValue>());
      expect(value.style, isA<KeywordStrokeStyle>());
    });

    test('rejects missing field', () {
      _parseValueExpectingError('border', <String, Object?>{
        'color': <String, Object?>{
          'colorSpace': 'srgb',
          'components': [0, 0, 0],
        },
        'style': 'solid',
      }, IssueCode.compositeMissingField);
    });
  });

  group('transition', () {
    test('inline', () {
      final value = _parseValue('transition', <String, Object?>{
        'duration': <String, Object?>{'value': 200, 'unit': 'ms'},
        'delay': <String, Object?>{'value': 0, 'unit': 'ms'},
        'timingFunction': const <num>[0.25, 0.1, 0.25, 1],
      }) as TransitionValue;
      expect(value.duration, isA<DurationValue>());
      expect(value.timingFunction, isA<CubicBezierValue>());
    });
  });

  group('shadow', () {
    test('single object', () {
      final value = _parseValue('shadow', <String, Object?>{
        'color': <String, Object?>{
          'colorSpace': 'srgb',
          'components': [0, 0, 0],
        },
        'offsetX': <String, Object?>{'value': 0, 'unit': 'px'},
        'offsetY': <String, Object?>{'value': 1, 'unit': 'px'},
        'blur': <String, Object?>{'value': 2, 'unit': 'px'},
        'spread': <String, Object?>{'value': 0, 'unit': 'px'},
      }) as SingleShadow;
      expect(value.shadow.inset, isFalse);
    });

    test('array with mixed shadow objects and references', () {
      final value = _parseValue('shadow', <Object?>[
        '{shadow.sm}',
        <String, Object?>{
          'color': <String, Object?>{
            'colorSpace': 'srgb',
            'components': [0, 0, 0],
          },
          'offsetX': <String, Object?>{'value': 0, 'unit': 'px'},
          'offsetY': <String, Object?>{'value': 4, 'unit': 'px'},
          'blur': <String, Object?>{'value': 8, 'unit': 'px'},
          'spread': <String, Object?>{'value': 0, 'unit': 'px'},
          'inset': true,
        },
      ]) as ListShadow;
      expect(value.entries, hasLength(2));
      expect(value.entries[0], isA<AliasValue>());
      expect(value.entries[1], isA<SingleShadow>());
      expect((value.entries[1] as SingleShadow).shadow.inset, isTrue);
    });
  });

  group('gradient', () {
    test('two stops', () {
      final value = _parseValue('gradient', <Object?>[
        <String, Object?>{
          'color': <String, Object?>{
            'colorSpace': 'srgb',
            'components': [0, 0, 0],
          },
          'position': 0,
        },
        <String, Object?>{
          'color': <String, Object?>{
            'colorSpace': 'srgb',
            'components': [1, 1, 1],
          },
          'position': 1,
        },
      ]) as GradientValue;
      expect(value.stops, hasLength(2));
      expect(value.stops[0], isA<GradientStopValue>());
    });

    test('positions outside [0,1] are clamped with a warning', () {
      final doc = <String, Object?>{
        'g': <String, Object?>{
          r'$type': 'gradient',
          r'$value': [
            <String, Object?>{
              'color': <String, Object?>{
                'colorSpace': 'srgb',
                'components': [0, 0, 0],
              },
              'position': -0.5,
            },
            <String, Object?>{
              'color': <String, Object?>{
                'colorSpace': 'srgb',
                'components': [1, 1, 1],
              },
              'position': 2,
            },
          ],
        },
      };
      final result = parseDocumentString(jsonEncode(doc));
      expect(result.hasErrors, isFalse);
      final warnings = result.issues
          .where((i) => i.code == IssueCode.gradientStopOutOfRange)
          .toList();
      expect(warnings, hasLength(2));
      final value =
          (result.document!.root.children['g']! as Token).value
              as GradientValue;
      final first = (value.stops[0] as GradientStopValue).stop;
      final second = (value.stops[1] as GradientStopValue).stop;
      expect((first.position as NumberValue).value, 0);
      expect((second.position as NumberValue).value, 1);
    });
  });

  group('typography', () {
    test('inline', () {
      final value = _parseValue('typography', <String, Object?>{
        'fontFamily': 'Roboto',
        'fontSize': <String, Object?>{'value': 16, 'unit': 'px'},
        'fontWeight': 'bold',
        'letterSpacing': <String, Object?>{'value': 0, 'unit': 'px'},
        'lineHeight': 1.4,
      }) as TypographyValue;
      expect(value.fontFamily, isA<FontFamilyValue>());
      expect(value.fontSize, isA<DimensionValue>());
      expect(value.fontWeight, isA<FontWeightValue>());
      expect(value.lineHeight, isA<NumberValue>());
    });
  });
}
