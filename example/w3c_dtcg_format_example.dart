// Loads a design-token document, prints every token and its resolved
// `$type` and `$value`, surfaces any validation issues, and round-trips
// the document back out.

import 'dart:io';

import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

const _sample = r'''
{
  "$description": "A tiny sample design-token document.",
  "color": {
    "$type": "color",
    "accent": {
      "$value": {
        "colorSpace": "srgb",
        "components": [0.2, 0.4, 0.6],
        "alpha": 1,
        "hex": "#336699"
      }
    },
    "muted": {
      "$value": {
        "colorSpace": "srgb",
        "components": [0.5, 0.5, 0.5]
      }
    }
  },
  "spacing": {
    "$type": "dimension",
    "sm": { "$value": { "value": 4, "unit": "px" } },
    "md": { "$value": { "value": 8, "unit": "px" } }
  },
  "button": {
    "background": { "$value": "{color.accent}" },
    "padding":    { "$value": "{spacing.md}" }
  }
}
''';

void main() {
  final result = parseDocumentString(_sample);

  if (result.issues.isNotEmpty) {
    stdout.writeln('Issues:');
    for (final issue in result.issues) {
      stdout.writeln('  $issue');
    }
  }
  if (!result.isValid) {
    stderr.writeln('document invalid — aborting');
    exitCode = 1;
    return;
  }

  final doc = result.document!;
  final resolver = TokenResolver(doc);

  stdout.writeln('\nTokens:');
  for (final entry in doc.walk()) {
    final node = entry.node;
    if (node is Token) {
      final type = resolver.resolveType(node);
      final resolved = resolver.resolveFully(node.value);
      stdout.writeln(
        '  ${entry.bracePath}: ${type?.name ?? "?"} = ${resolved.toJson()}',
      );
    }
  }

  // Second-pass reference validation.
  final refIssues = resolver.validateReferences();
  if (refIssues.isNotEmpty) {
    stdout.writeln('\nReference issues:');
    for (final issue in refIssues) {
      stdout.writeln('  $issue');
    }
  }

  // Round-trip back to JSON.
  stdout.writeln('\nRound-tripped JSON:');
  stdout.writeln(doc.encode());
}
