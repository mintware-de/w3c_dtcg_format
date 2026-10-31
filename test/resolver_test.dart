import 'package:test/test.dart';
import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

TokenResolver _parse(String json) {
  final result = parseDocumentString(json);
  expect(result.isValid, isTrue, reason: result.issues.toString());
  return TokenResolver(result.document!);
}

void main() {
  group('alias chains', () {
    test('A -> B -> C -> concrete', () {
      final resolver = _parse(r'''
        {
          "$type": "number",
          "a": { "$value": "{b}" },
          "b": { "$value": "{c}" },
          "c": { "$value": 42 }
        }
      ''');
      final a = resolver.document.lookupBracePath('a')! as Token;
      final resolved = resolver.resolveFully(a.value);
      expect(resolved, isA<NumberValue>());
      expect((resolved as NumberValue).value, 42);
    });

    test('cycle is detected and does not loop', () {
      final result = parseDocumentString(r'''
        {
          "$type": "number",
          "a": { "$value": "{b}" },
          "b": { "$value": "{a}" }
        }
      ''');
      expect(result.isValid, isTrue);
      final resolver = TokenResolver(result.document!);
      final issues = resolver.validateReferences();
      final cycle = issues
          .where((i) => i.code == IssueCode.aliasCycle)
          .toList();
      expect(cycle, isNotEmpty);
    });

    test('dangling alias is reported', () {
      final result = parseDocumentString(r'''
        {
          "$type": "number",
          "a": { "$value": "{does.not.exist}" }
        }
      ''');
      final resolver = TokenResolver(result.document!);
      final issues = resolver.validateReferences();
      expect(issues.map((i) => i.code), contains(IssueCode.aliasNotFound));
    });

    test('type is inferred from alias target', () {
      final resolver = _parse(r'''
        {
          "color": {
            "$type": "color",
            "accent": { "$value": { "colorSpace": "srgb", "components": [1, 0, 0] } }
          },
          "button": { "background": { "$value": "{color.accent}" } }
        }
      ''');
      final background =
          resolver.document.lookupBracePath('button.background')! as Token;
      expect(resolver.resolveType(background), TokenType.color);
    });
  });

  group('composite resolution', () {
    test('BorderValue sub-fields resolve', () {
      final resolver = _parse(r'''
        {
          "color": {
            "$type": "color",
            "accent": { "$value": { "colorSpace": "srgb", "components": [1, 0, 0] } }
          },
          "sizes": {
            "$type": "dimension",
            "stroke": { "$value": { "value": 2, "unit": "px" } }
          },
          "ui": {
            "button-border": {
              "$type": "border",
              "$value": {
                "color": "{color.accent}",
                "width": "{sizes.stroke}",
                "style": "solid"
              }
            }
          }
        }
      ''');
      final border =
          resolver.document.lookupBracePath('ui.button-border')! as Token;
      final resolved = resolver.resolveFully(border.value) as BorderValue;
      expect(resolved.color, isA<ColorValue>());
      expect(resolved.width, isA<DimensionValue>());
      expect(resolved.style, isA<KeywordStrokeStyle>());
    });

    test('array elements inside shadow resolve individually', () {
      final resolver = _parse(r'''
        {
          "shadow": {
            "$type": "shadow",
            "sm": {
              "$value": {
                "color": { "colorSpace": "srgb", "components": [0, 0, 0], "alpha": 0.1 },
                "offsetX": { "value": 0, "unit": "px" },
                "offsetY": { "value": 1, "unit": "px" },
                "blur":    { "value": 2, "unit": "px" },
                "spread":  { "value": 0, "unit": "px" }
              }
            },
            "layered": {
              "$value": [
                "{shadow.sm}",
                {
                  "color": { "colorSpace": "srgb", "components": [0, 0, 0], "alpha": 0.2 },
                  "offsetX": { "value": 0, "unit": "px" },
                  "offsetY": { "value": 4, "unit": "px" },
                  "blur":    { "value": 8, "unit": "px" },
                  "spread":  { "value": 0, "unit": "px" }
                }
              ]
            }
          }
        }
      ''');
      final layered =
          resolver.document.lookupBracePath('shadow.layered')! as Token;
      final resolved = resolver.resolveFully(layered.value) as ListShadow;
      expect(resolved.entries, hasLength(2));
      // First element was an alias → now a SingleShadow concrete.
      expect(resolved.entries[0], isA<SingleShadow>());
      expect(resolved.entries[1], isA<SingleShadow>());
    });
  });

  group('\$ref', () {
    test('resolveRefRaw walks into composite', () {
      final resolver = _parse(r'''
        {
          "color": {
            "$type": "color",
            "accent": { "$value": { "colorSpace": "srgb", "components": [1, 0, 0] } }
          }
        }
      ''');
      final raw = resolver.resolveRefRaw(r'/color/accent/$value/components/0');
      expect(raw, 1);
    });

    test('\$ref targeting a token infers that token\'s type', () {
      final resolver = _parse(r'''
        {
          "color": {
            "$type": "color",
            "accent": { "$value": { "colorSpace": "srgb", "components": [1, 0, 0] } }
          },
          "untyped": { "$value": { "$ref": "/color/accent" } }
        }
      ''');
      final untyped = resolver.document.lookupBracePath('untyped')! as Token;
      expect(resolver.resolveType(untyped), TokenType.color);
    });

    test('missing \$ref is reported', () {
      final result = parseDocumentString(r'''
        {
          "a": { "$type": "number", "$value": { "$ref": "/nope" } }
        }
      ''');
      final resolver = TokenResolver(result.document!);
      final issues = resolver.validateReferences();
      expect(issues.map((i) => i.code), contains(IssueCode.refNotFound));
    });
  });

  group('\$extends', () {
    test('resolves to a group', () {
      final resolver = _parse(r'''
        {
          "base": {
            "$type": "color",
            "accent": { "$value": { "colorSpace": "srgb", "components": [1, 0, 0] } }
          },
          "ext": {
            "$extends": "/base"
          }
        }
      ''');
      final ext = resolver.document.lookupBracePath('ext')! as Group;
      expect(resolver.resolveExtends(ext), isNotNull);
    });

    test('missing target is reported', () {
      final result = parseDocumentString(r'''
        { "ext": { "$extends": "/nope" } }
      ''');
      final resolver = TokenResolver(result.document!);
      final issues = resolver.validateReferences();
      expect(issues.map((i) => i.code), contains(IssueCode.extendsNotFound));
    });

    test('target is a token → error', () {
      final result = parseDocumentString(r'''
        {
          "t": { "$type": "number", "$value": 1 },
          "ext": { "$extends": "/t" }
        }
      ''');
      final resolver = TokenResolver(result.document!);
      final issues = resolver.validateReferences();
      expect(
        issues.map((i) => i.code),
        contains(IssueCode.extendsTargetsToken),
      );
    });

    test('cycle is detected', () {
      final result = parseDocumentString(r'''
        {
          "a": { "$extends": "/b" },
          "b": { "$extends": "/a" }
        }
      ''');
      final resolver = TokenResolver(result.document!);
      final issues = resolver.validateReferences();
      expect(issues.map((i) => i.code), contains(IssueCode.extendsCycle));
    });
  });
}
