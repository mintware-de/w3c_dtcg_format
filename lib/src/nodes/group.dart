part of 'nodes.dart';

/// A container holding tokens and/or sub-groups (§5.1).
final class Group extends DesignTokenNode {
  Group({
    required Map<String, DesignTokenNode> children,
    this.extendsRef,
    super.description,
    super.deprecation,
    super.extensions,
    super.ownType,
  }) : children = Map<String, DesignTokenNode>.unmodifiable(children);

  /// Child entries in source order. Keys are the user-authored names.
  final Map<String, DesignTokenNode> children;

  /// The `$extends` JSON Pointer, when this group inherits from another
  /// group (§6.4). Group-only; tokens never carry this.
  final String? extendsRef;

  /// Builds the JSON object this group round-trips to.
  Map<String, Object?> toJson() {
    final out = <String, Object?>{};
    final nodeType = ownType;
    if (nodeType != null) out[r'$type'] = nodeType;
    final desc = description;
    if (desc != null) out[r'$description'] = desc;
    final dep = deprecation;
    if (dep != null) out[r'$deprecated'] = dep.toJson();
    final ext = extensions;
    if (ext != null) out[r'$extensions'] = Map<String, Object?>.from(ext);
    final extRef = extendsRef;
    if (extRef != null) out[r'$extends'] = extRef;
    for (final entry in children.entries) {
      out[entry.key] = switch (entry.value) {
        final Token t => t.toJson(),
        final Group g => g.toJson(),
      };
    }
    return out;
  }

  @override
  String toString() =>
      'Group(ownType=$ownType, ${children.length} children'
      '${extendsRef == null ? '' : ', extends=$extendsRef'}'
      ')';
}
