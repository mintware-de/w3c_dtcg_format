[![CI](https://github.com/mintware-de/w3c_dtcg_format/actions/workflows/ci.yml/badge.svg)](https://github.com/mintware-de/w3c_dtcg_format/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/w3c_dtcg_format.svg)](https://pub.dev/packages/w3c_dtcg_format)
[![pub points](https://img.shields.io/pub/points/w3c_dtcg_format)](https://pub.dev/packages/w3c_dtcg_format/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

# w3c_dtcg_format

A Dart implementation of the
[W3C Design Tokens Community Group Format Module, revision 2025.10](https://www.designtokens.org/tr/2025.10/format/)
and its companion
[Color Module](https://www.designtokens.org/tr/2025.10/color/).

The package reads a `.tokens` or `.tokens.json` document into a typed Dart
model, validates it against the spec, resolves `{alias}` and `$ref` chains
(with cycle detection), and serializes the model back to spec-compliant JSON
without touching unresolved references.

## Features

- **Full round-trip** parse → validate → resolve → serialize. Unresolved
  aliases survive the round trip verbatim.
- **Strict validation with an error collector.** Every spec rule that says
  `MUST` becomes an error; every `SHOULD` becomes a warning. All issues carry
  an RFC 6901 JSON Pointer path so callers can show every problem at once.
- **All 2025.10 primitive and composite types** supported: `color` (14 color
  spaces, including the new `none` component keyword), `dimension`,
  `fontFamily`, `fontWeight` (numeric or keyword), `duration`, `cubicBezier`,
  `number`, `strokeStyle`, `border`, `transition`, `shadow` (single or
  layered), `gradient`, `typography`.
- **Both alias syntaxes**: the brace form `"{group.token}"` and the
  `$ref` JSON Pointer form.
- **`$type` inheritance** cascades from groups to children (with
  override), and inference from alias targets.
- **`$extends`** group inheritance with override semantics and cycle
  detection.
- **`$extensions`** preserved verbatim (opaque to the parser).

## Usage

```dart
import 'dart:io';

import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

void main() {
  final source = File('tokens/system.tokens.json').readAsStringSync();
  final result = parseDocumentString(source);

  for (final issue in result.issues) {
    stderr.writeln('[${issue.severity.name}] ${issue.path}: ${issue.message}');
  }
  if (!result.isValid) {
    exit(1);
  }

  final doc = result.document!;
  final resolver = TokenResolver(doc);

  for (final entry in doc.walk()) {
    if (entry.node is Token) {
      final token = entry.node as Token;
      final resolved = resolver.resolveFully(token.value);
      print('${entry.path}: ${resolver.resolveType(token)} = $resolved');
    }
  }

  // Round-trip back to JSON.
  File('tokens/system.round-trip.tokens.json')
      .writeAsStringSync(doc.encode(indent: true));
}
```

## Spec coverage

Covers revision 2025.10, dated 28 October 2025. Non-normative §8.8 types
(`font-style`, `percentage`/`ratio`, `file`) are recognized as unknown types
with a warning, as the spec defers their shape.
