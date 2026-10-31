part of 'values.dart';

/// A brace-syntax reference: `"{group.subgroup.tokenName}"`.
///
/// The [path] holds the inner string without the surrounding braces, and
/// is dot-separated per §7.1.1. Resolution always targets the referenced
/// token's `$value`; it cannot address inside composite sub-fields (see
/// [RefValue] for that).
final class AliasValue extends TokenValue {
  const AliasValue(this.path);

  final String path;

  /// The path split on `.`.
  List<String> get segments => path.split('.');

  @override
  Object toJson() => '{$path}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AliasValue && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'AliasValue({$path})';
}

/// A JSON Pointer reference per RFC 6901, serialized as `{"$ref": "..."}`.
///
/// Unlike [AliasValue], a [RefValue] can address a composite sub-field or
/// a specific array element.
final class RefValue extends TokenValue {
  const RefValue(this.pointer);

  final String pointer;

  @override
  Object toJson() => <String, Object?>{r'$ref': pointer};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RefValue && other.pointer == pointer;

  @override
  int get hashCode => pointer.hashCode;

  @override
  String toString() => 'RefValue($pointer)';
}

/// Tries to interpret [raw] as a reference.
///
/// Returns an [AliasValue] when [raw] is a brace-syntax string, a
/// [RefValue] when it is a single-entry `{"$ref": ...}` object, or `null`
/// otherwise. Only syntactic recognition is attempted — target existence
/// is a resolver concern.
TokenValue? tryParseReference(Object? raw, ErrorCollector errors) {
  if (raw is String && raw.startsWith('{') && raw.endsWith('}')) {
    return _tryParseStringReference(raw, errors);
  } else if (raw is Map && raw.length == 1 && raw.containsKey(r'$ref')) {
    return _tryParseMapReference(raw, errors);
  }
  return null;
}

RefValue? _tryParseMapReference(
  Map<dynamic, dynamic> raw,
  ErrorCollector errors,
) {
  final ref = raw[r'$ref'];
  if (ref is! String) {
    errors.error(IssueCode.invalidRefSyntax, r'$ref value must be a string');
    return null;
  }
  return RefValue(ref);
}

AliasValue? _tryParseStringReference(String raw, ErrorCollector errors) {
  final inner = raw.substring(1, raw.length - 1);
  if (inner.contains('{') || inner.contains('}')) {
    errors.error(
      IssueCode.invalidAliasSyntax,
      'alias reference must not contain nested braces',
    );
    return null;
  }
  if (inner.isEmpty) {
    errors.error(
      IssueCode.invalidAliasSyntax,
      'alias reference path must not be empty',
    );
    return null;
  }
  return AliasValue(inner);
}
