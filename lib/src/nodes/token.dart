part of 'nodes.dart';

/// A single design token — an object with a `$value` property (§5.1).
final class Token extends DesignTokenNode {
  const Token({
    required this.value,
    super.description,
    super.deprecation,
    super.extensions,
    super.ownType,
  });

  /// The parsed `$value` of this token.
  final TokenValue value;

  /// Builds the JSON object this token round-trips to.
  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    final nodeType = ownType;
    if (nodeType != null) out[r'$type'] = nodeType;
    out[r'$value'] = value.toJson();
    final desc = description;
    if (desc != null) out[r'$description'] = desc;
    final dep = deprecation;
    if (dep != null) out[r'$deprecated'] = dep.toJson();
    final ext = extensions;
    if (ext != null) out[r'$extensions'] = Map<String, Object?>.from(ext);
    return out;
  }

  @override
  String toString() =>
      'Token(ownType=$ownType, value=$value'
      '${description == null ? '' : ', description="$description"'}'
      '${deprecation == null ? '' : ', deprecation=$deprecation'}'
      ')';
}
