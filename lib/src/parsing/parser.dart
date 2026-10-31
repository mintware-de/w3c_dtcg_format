import 'dart:convert';

import '../document.dart';
import '../nodes/nodes.dart';
import '../parse_result.dart';
import '../util/json_pointer.dart';
import '../validation/error_collector.dart';
import '../validation/issue.dart';
import '../validation/name_validator.dart';
import '../values/values.dart';
import 'visitor.dart';

/// Parses a decoded JSON object as a DTCG document.
///
/// When [preVisit] is non-null it fires on the root and on every JSON
/// object that would become a `Group` or `Token`, BEFORE `$type`
/// resolution and `$value` parsing. See [NodePreVisitor].
ParseResult parseDocument(
  Map<String, Object?> json, {
  NodePreVisitor? preVisit,
}) {
  final errors = ErrorCollector();
  final rootRaw = preVisit == null
      ? json
      : preVisit(
          const NodeVisitContext(
            jsonPointer: '',
            segments: <String>[],
            inheritedType: null,
            isRoot: true,
          ),
          json,
        );
  final root = _parseGroup(rootRaw, null, const <String>[], errors, preVisit);
  return ParseResult(
    document: DesignTokenDocument(root),
    issues: errors.issues,
  );
}

/// Decodes [source] as JSON and parses the result. Returns a result whose
/// [ParseResult.document] is `null` when [source] is not valid JSON or when
/// the root is not an object.
ParseResult parseDocumentString(String source, {NodePreVisitor? preVisit}) {
  final errors = ErrorCollector();
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    errors.error(
      IssueCode.nonObjectRoot,
      'input is not valid JSON: ${e.message}',
    );
    return ParseResult(document: null, issues: errors.issues);
  }
  if (decoded is! Map<String, Object?>) {
    errors.error(
      IssueCode.nonObjectRoot,
      'document root must be a JSON object',
    );
    return ParseResult(document: null, issues: errors.issues);
  }
  return parseDocument(decoded, preVisit: preVisit);
}

Group _parseGroup(
  Map<Object?, Object?> raw,
  String? inheritedType,
  List<String> segments,
  ErrorCollector errors,
  NodePreVisitor? preVisit,
) {
  final meta = _parseMeta(raw, errors, isGroup: true);
  final effectiveType = meta.ownType ?? inheritedType;

  final children = <String, DesignTokenNode>{};
  final seenNamesByLower = <String, String>{};

  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) continue;
    if (key.startsWith(r'$')) {
      if (!knownDollarProperties.contains(key)) {
        errors.warningAt(
          key,
          IssueCode.unknownDollarProperty,
          'unknown "\$"-prefixed property "$key"',
        );
      }
      continue;
    }
    final nameError = validateName(key);
    if (nameError != null) {
      errors.errorAt(key, IssueCode.invalidName, nameError);
      continue;
    }
    final lower = key.toLowerCase();
    final existing = seenNamesByLower[lower];
    if (existing != null && existing != key) {
      errors.warningAt(
        key,
        IssueCode.caseInsensitiveNameCollision,
        'sibling names "$existing" and "$key" differ only in case',
      );
    }
    seenNamesByLower[lower] = key;

    final childSegments = <String>[...segments, key];
    final rawChild = entry.value;
    final visitedChild = (preVisit != null && rawChild is Map<String, Object?>)
        ? preVisit(
            NodeVisitContext(
              jsonPointer: encodeJsonPointer(childSegments),
              segments: List<String>.unmodifiable(childSegments),
              inheritedType: effectiveType,
              isRoot: false,
            ),
            rawChild,
          )
        : rawChild;

    final child = errors.withSegment(key, () {
      return _parseNode(
        visitedChild,
        effectiveType,
        childSegments,
        errors,
        preVisit,
      );
    });
    if (child != null) {
      children[key] = child;
    }
  }

  return Group(
    children: children,
    extendsRef: meta.extendsRef,
    description: meta.description,
    deprecation: meta.deprecation,
    extensions: meta.extensions,
    ownType: meta.ownType,
  );
}

DesignTokenNode? _parseNode(
  Object? raw,
  String? inheritedType,
  List<String> segments,
  ErrorCollector errors,
  NodePreVisitor? preVisit,
) {
  if (raw is! Map) {
    errors.error(
      IssueCode.valueWrongShape,
      'document entry must be a JSON object',
    );
    return null;
  }
  if (raw.containsKey(r'$value')) {
    return _parseToken(raw, inheritedType, errors);
  }
  return _parseGroup(raw, inheritedType, segments, errors, preVisit);
}

Token? _parseToken(
  Map<Object?, Object?> raw,
  String? inheritedType,
  ErrorCollector errors,
) {
  // A token MUST NOT also contain child-token/group entries (§5.1).
  for (final key in raw.keys) {
    if (key is String && !key.startsWith(r'$')) {
      errors.error(
        IssueCode.tokenAndChildrenConflict,
        'object has both "\$value" and child entry "$key"',
      );
      break;
    }
  }

  final meta = _parseMeta(raw, errors, isGroup: false);

  final effectiveTypeName = meta.ownType ?? inheritedType;
  TokenType? effectiveType;
  if (effectiveTypeName != null) {
    effectiveType = TokenType.byName(effectiveTypeName);
    if (effectiveType == null) {
      errors.warning(
        IssueCode.unknownType,
        'unknown \$type "$effectiveTypeName"; token will accept only aliases',
      );
    }
  }

  final rawValue = raw[r'$value'];
  final value = errors.withSegment(r'$value', () {
    return parseTokenValue(effectiveType, rawValue, errors);
  });
  if (value == null) return null;

  return Token(
    value: value,
    description: meta.description,
    deprecation: meta.deprecation,
    extensions: meta.extensions,
    ownType: meta.ownType,
  );
}

class _ParsedMeta {
  _ParsedMeta();

  String? description;
  Deprecation? deprecation;
  Map<String, Object?>? extensions;
  String? ownType;
  String? extendsRef;
}

_ParsedMeta _parseMeta(
  Map<Object?, Object?> raw,
  ErrorCollector errors, {
  required bool isGroup,
}) {
  final meta = _ParsedMeta();

  final rawType = raw[r'$type'];
  if (rawType != null) {
    if (rawType is String) {
      meta.ownType = rawType;
    } else {
      errors.errorAt(
        r'$type',
        IssueCode.typeNotAString,
        '\$type must be a string',
      );
    }
  }

  final rawDescription = raw[r'$description'];
  if (rawDescription != null) {
    if (rawDescription is String) {
      meta.description = rawDescription;
    } else {
      errors.warningAt(
        r'$description',
        IssueCode.valueWrongShape,
        '\$description SHOULD be a string',
      );
    }
  }

  if (raw.containsKey(r'$deprecated')) {
    final rawDeprecated = raw[r'$deprecated'];
    if (rawDeprecated is bool) {
      meta.deprecation = Deprecation.flag(rawDeprecated);
    } else if (rawDeprecated is String) {
      meta.deprecation = Deprecation.reason(rawDeprecated);
    } else {
      errors.warningAt(
        r'$deprecated',
        IssueCode.valueWrongShape,
        '\$deprecated must be a boolean or a string',
      );
    }
  }

  final rawExtensions = raw[r'$extensions'];
  if (rawExtensions != null) {
    if (rawExtensions is Map) {
      meta.extensions = Map<String, Object?>.fromEntries(
        rawExtensions.entries
            .where((e) => e.key is String)
            .map((e) => MapEntry(e.key! as String, e.value)),
      );
    } else {
      errors.warningAt(
        r'$extensions',
        IssueCode.valueWrongShape,
        '\$extensions SHOULD be a JSON object',
      );
    }
  }

  if (raw.containsKey(r'$extends')) {
    if (!isGroup) {
      errors.errorAt(
        r'$extends',
        IssueCode.extendsOnToken,
        '\$extends is group-only; it has no effect on a token',
      );
    } else {
      final rawExtends = raw[r'$extends'];
      if (rawExtends is String) {
        meta.extendsRef = rawExtends;
      } else {
        errors.errorAt(
          r'$extends',
          IssueCode.valueWrongShape,
          '\$extends must be a JSON Pointer string',
        );
      }
    }
  }

  return meta;
}
