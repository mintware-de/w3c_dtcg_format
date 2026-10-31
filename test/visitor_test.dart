import 'package:test/test.dart';
import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

void main() {
  group('preVisit hook', () {
    test('is not called when the callback is null (default behaviour)', () {
      final result = parseDocumentString(r'''
        { "a": { "$type": "number", "$value": 1 } }
      ''');
      expect(result.isValid, isTrue);
    });

    test('fires on the root with isRoot=true and empty segments', () {
      final seen = <NodeVisitContext>[];
      parseDocumentString(
        r'{ "a": { "$type": "number", "$value": 1 } }',
        preVisit: (ctx, raw) {
          seen.add(ctx);
          return raw;
        },
      );
      expect(seen, isNotEmpty);
      final root = seen.first;
      expect(root.isRoot, isTrue);
      expect(root.jsonPointer, '');
      expect(root.segments, isEmpty);
      expect(root.inheritedType, isNull);
    });

    test('fires once per JSON object that becomes a node', () {
      final paths = <String>[];
      parseDocumentString(
        r'''
          {
            "a": {
              "$type": "number",
              "b": { "$value": 1 },
              "c": { "$value": 2 }
            }
          }
        ''',
        preVisit: (ctx, raw) {
          paths.add(ctx.jsonPointer);
          return raw;
        },
      );
      // Root, /a, /a/b, /a/c — four nodes.
      expect(paths, ['', '/a', '/a/b', '/a/c']);
    });

    test('reports inheritedType strictly from ancestors', () {
      final seen = <String, String?>{};
      parseDocumentString(
        r'''
          {
            "$type": "color",
            "spacing": {
              "$type": "dimension",
              "sm": { "$value": { "value": 4, "unit": "px" } }
            }
          }
        ''',
        preVisit: (ctx, raw) {
          seen[ctx.jsonPointer] = ctx.inheritedType;
          return raw;
        },
      );
      expect(seen[''], isNull);
      expect(seen['/spacing'], 'color');
      expect(seen['/spacing/sm'], 'dimension');
    });

    test('mutating \$type via the visitor affects downstream parsing', () {
      final result = parseDocumentString(
        r'{ "x": { "$type": "foo", "$value": 42 } }',
        preVisit: (ctx, raw) {
          if (raw[r'$type'] == 'foo') {
            return <String, Object?>{...raw, r'$type': 'number'};
          }
          return raw;
        },
      );
      expect(result.isValid, isTrue, reason: result.issues.toString());
      final token = result.document!.root.children['x']! as Token;
      expect(token.value, isA<NumberValue>());
    });

    test('mutating \$value wraps a scalar as a dimension', () {
      final result = parseDocumentString(
        r'{ "x": { "$type": "number", "$value": 12 } }',
        preVisit: (ctx, raw) {
          if (ctx.jsonPointer == '/x') {
            return <String, Object?>{
              ...raw,
              r'$type': 'dimension',
              r'$value': <String, Object?>{
                'value': raw[r'$value'],
                'unit': 'px',
              },
            };
          }
          return raw;
        },
      );
      expect(result.isValid, isTrue, reason: result.issues.toString());
      final token = result.document!.root.children['x']! as Token;
      expect(token.value, isA<DimensionValue>());
      expect((token.value as DimensionValue).value, 12);
      expect((token.value as DimensionValue).unit, DimensionUnit.px);
    });

    test('exceptions in the visitor propagate', () {
      expect(
        () => parseDocumentString(
          '{"a": {"\$value": 1, "\$type": "number"}}',
          preVisit: (ctx, raw) => throw StateError('nope'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
