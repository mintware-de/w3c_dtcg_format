import 'package:test/test.dart';
import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

void main() {
  group('document structure', () {
    test('empty document', () {
      final result = parseDocumentString('{}');
      expect(result.isValid, isTrue);
      expect(result.document!.root.children, isEmpty);
    });

    test('rejects non-object root', () {
      final result = parseDocumentString('[]');
      expect(result.hasErrors, isTrue);
      expect(result.document, isNull);
      expect(result.issues.first.code, IssueCode.nonObjectRoot);
    });

    test('rejects malformed JSON', () {
      final result = parseDocumentString('not json');
      expect(result.hasErrors, isTrue);
      expect(result.document, isNull);
    });

    test('token with child entry is rejected', () {
      final result = parseDocumentString(r'''
        {
          "t": {
            "$value": "{x}",
            "nested": { "$value": "{x}" }
          }
        }
      ''');
      expect(
        result.issues.map((i) => i.code),
        contains(IssueCode.tokenAndChildrenConflict),
      );
    });

    test(r'name with "{", "}", or "." is rejected', () {
      for (final name in ['with{brace', 'with}brace', 'with.dot']) {
        final doc = '{"$name": {"\$value": 1, "\$type": "number"}}';
        final result = parseDocumentString(doc);
        expect(
          result.issues.map((i) => i.code),
          contains(IssueCode.invalidName),
          reason: 'name "$name" should be rejected',
        );
      }
    });

    test(r'$-prefixed sibling key that is not a known meta property is a warning, not a name error', () {
      // $-prefixed keys never make it to child-naming at all — the parser
      // treats them as meta properties and surfaces unknown ones as
      // IssueCode.unknownDollarProperty. The reservation of $-prefix in
      // §5.1.1 is in effect because such keys cannot be children.
      final result = parseDocumentString(
        '{"\$private": "nope", "a": {"\$type": "number", "\$value": 1}}',
      );
      expect(result.isValid, isTrue);
      expect(
        result.issues.map((i) => i.code),
        contains(IssueCode.unknownDollarProperty),
      );
    });

    test('case-insensitive sibling collision is a warning', () {
      final result = parseDocumentString(r'''
        {
          "$type": "number",
          "Primary": { "$value": 1 },
          "primary": { "$value": 2 }
        }
      ''');
      expect(result.hasErrors, isFalse);
      expect(
        result.issues.map((i) => i.code),
        contains(IssueCode.caseInsensitiveNameCollision),
      );
    });

    test('unknown dollar property is a warning', () {
      final result = parseDocumentString(r'''
        {
          "$custom": "oops",
          "a": { "$type": "number", "$value": 1 }
        }
      ''');
      expect(result.hasErrors, isFalse);
      expect(
        result.issues.map((i) => i.code),
        contains(IssueCode.unknownDollarProperty),
      );
    });
  });

  group('meta properties', () {
    test(r'$description, $deprecated (bool), $extensions preserved', () {
      final result = parseDocumentString(r'''
        {
          "a": {
            "$type": "number",
            "$value": 1,
            "$description": "the alpha value",
            "$deprecated": true,
            "$extensions": { "com.example.foo": { "flag": true } }
          }
        }
      ''');
      expect(result.isValid, isTrue);
      final token = result.document!.root.children['a']! as Token;
      expect(token.description, 'the alpha value');
      expect(token.deprecation, isA<DeprecationFlag>());
      expect(token.deprecation!.isDeprecated, isTrue);
      expect(token.extensions, {
        'com.example.foo': {'flag': true},
      });
    });

    test(r'$deprecated as string is a reason', () {
      final result = parseDocumentString(r'''
        {
          "a": {
            "$type": "number",
            "$value": 1,
            "$deprecated": "use b instead"
          }
        }
      ''');
      final token = result.document!.root.children['a']! as Token;
      expect(token.deprecation, isA<DeprecationReason>());
      expect((token.deprecation! as DeprecationReason).reason, 'use b instead');
    });

    test(r'$extends on a token is an error', () {
      final result = parseDocumentString(r'''
        {
          "a": {
            "$type": "number",
            "$value": 1,
            "$extends": "#/other"
          }
        }
      ''');
      expect(
        result.issues.map((i) => i.code),
        contains(IssueCode.extendsOnToken),
      );
    });
  });

  group(r'$type inheritance', () {
    test('inherited from immediate parent group', () {
      final result = parseDocumentString(r'''
        {
          "color": {
            "$type": "color",
            "red": { "$value": { "colorSpace": "srgb", "components": [1, 0, 0] } }
          }
        }
      ''');
      expect(result.isValid, isTrue);
      final red = result.document!.lookupBracePath('color.red')! as Token;
      expect(red.ownType, isNull);
      final resolver = TokenResolver(result.document!);
      expect(resolver.resolveType(red), TokenType.color);
    });

    test('nearest ancestor wins when nested', () {
      final result = parseDocumentString(r'''
        {
          "$type": "color",
          "spacing": {
            "$type": "dimension",
            "sm": { "$value": { "value": 4, "unit": "px" } }
          }
        }
      ''');
      expect(result.isValid, isTrue);
      final sm = result.document!.lookupBracePath('spacing.sm')! as Token;
      final resolver = TokenResolver(result.document!);
      expect(resolver.resolveType(sm), TokenType.dimension);
    });

    test('own type beats inheritance', () {
      final result = parseDocumentString(r'''
        {
          "$type": "color",
          "weird": {
            "$type": "number",
            "$value": 42
          }
        }
      ''');
      expect(result.isValid, isTrue);
      final weird = result.document!.lookupBracePath('weird')! as Token;
      final resolver = TokenResolver(result.document!);
      expect(resolver.resolveType(weird), TokenType.number);
    });

    test('missing type on non-alias value is an error', () {
      final result = parseDocumentString(r'''
        { "lonely": { "$value": 42 } }
      ''');
      expect(result.issues.map((i) => i.code), contains(IssueCode.missingType));
    });
  });
}
