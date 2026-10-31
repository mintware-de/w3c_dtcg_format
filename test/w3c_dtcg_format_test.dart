import 'package:test/test.dart';
import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

/// Smoke test: everything in the public API wires together on a tiny
/// representative document.
void main() {
  test('parses, resolves and round-trips a basic document', () {
    const source = r'''
      {
        "color": {
          "$type": "color",
          "accent": {
            "$value": {
              "colorSpace": "srgb",
              "components": [1, 0, 0]
            }
          }
        },
        "aliased": { "$value": "{color.accent}" }
      }
    ''';

    final result = parseDocumentString(source);
    expect(result.isValid, isTrue, reason: result.issues.toString());

    final doc = result.document!;
    final resolver = TokenResolver(doc);

    final aliased = doc.lookupBracePath('aliased');
    expect(aliased, isA<Token>());
    expect(resolver.resolveType(aliased!), TokenType.color);

    final resolved = resolver.resolveFully((aliased as Token).value);
    expect(resolved, isA<ColorValue>());
    expect((resolved as ColorValue).components, [
      const ComponentNumber(1),
      const ComponentNumber(0),
      const ComponentNumber(0),
    ]);

    // Reference validation sees no issues.
    expect(resolver.validateReferences(), isEmpty);

    // Round-trip survives.
    final roundTripped = parseDocumentString(doc.encode());
    expect(roundTripped.isValid, isTrue);
  });
}
