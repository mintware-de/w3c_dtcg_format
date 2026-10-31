import 'dart:convert';

import 'package:test/test.dart';
import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';

/// A thorough document that uses every type the spec defines, plus the
/// two alias syntaxes. If `parse → encode → parse` preserves the first
/// result's structure, the round-trip contract holds.
const _kitchenSink = r'''
{
  "$description": "Kitchen-sink round-trip fixture",
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
        "colorSpace": "oklch",
        "components": [0.7, "none", 180]
      }
    }
  },
  "spacing": {
    "$type": "dimension",
    "sm": { "$value": { "value": 4, "unit": "px" } },
    "md": { "$value": { "value": 1.5, "unit": "rem" } }
  },
  "typography": {
    "$type": "typography",
    "heading": {
      "$value": {
        "fontFamily": ["Roboto", "sans-serif"],
        "fontSize": { "value": 36, "unit": "px" },
        "fontWeight": "bold",
        "letterSpacing": { "value": 0, "unit": "px" },
        "lineHeight": 1.2
      }
    }
  },
  "motion": {
    "$type": "transition",
    "snap": {
      "$value": {
        "duration": { "value": 200, "unit": "ms" },
        "delay": { "value": 0, "unit": "ms" },
        "timingFunction": [0.25, 0.1, 0.25, 1]
      }
    }
  },
  "stroke": {
    "$type": "strokeStyle",
    "dashed": { "$value": "dashed" },
    "custom": {
      "$value": {
        "dashArray": [{"value": 4, "unit": "px"}, {"value": 2, "unit": "px"}],
        "lineCap": "round"
      }
    }
  },
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
    "stacked": {
      "$value": [
        "{shadow.sm}",
        {
          "color": { "colorSpace": "srgb", "components": [0, 0, 0], "alpha": 0.2 },
          "offsetX": { "value": 0, "unit": "px" },
          "offsetY": { "value": 4, "unit": "px" },
          "blur":    { "value": 8, "unit": "px" },
          "spread":  { "value": 0, "unit": "px" },
          "inset": true
        }
      ]
    }
  },
  "gradients": {
    "$type": "gradient",
    "bg": {
      "$value": [
        { "color": { "colorSpace": "srgb", "components": [0, 0, 0] }, "position": 0 },
        { "color": "{color.accent}", "position": 0.5 },
        { "color": { "colorSpace": "srgb", "components": [1, 1, 1] }, "position": 1 }
      ]
    }
  },
  "borders": {
    "$type": "border",
    "default": {
      "$value": {
        "color": "{color.accent}",
        "width": "{spacing.sm}",
        "style": "solid"
      }
    }
  },
  "ref": {
    "$type": "color",
    "accent": { "$value": { "$ref": "/color/accent/$value" } }
  }
}
''';

void main() {
  test('kitchen sink parses with no issues', () {
    final result = parseDocumentString(_kitchenSink);
    expect(result.isValid, isTrue, reason: result.issues.toString());
  });

  test('parse → encode → parse yields the same shape', () {
    final first = parseDocumentString(_kitchenSink);
    expect(first.isValid, isTrue);
    final encoded = first.document!.encode(indent: false);
    final second = parseDocumentString(encoded);
    expect(second.isValid, isTrue, reason: second.issues.toString());

    // Direct JSON equality (modulo map ordering, which jsonDecode preserves):
    final firstJson = jsonDecode(encoded);
    final secondJson = jsonDecode(second.document!.encode(indent: false));
    expect(secondJson, firstJson);
  });

  test('unresolved alias survives round-trip verbatim', () {
    final result = parseDocumentString(r'''
      {
        "a": { "$type": "number", "$value": "{missing.target}" }
      }
    ''');
    // The alias is syntactically valid; validate() surfaces the missing
    // target but the Token itself still parses.
    expect(
      result.document!.encode(indent: false),
      contains('{missing.target}'),
    );
  });
}
