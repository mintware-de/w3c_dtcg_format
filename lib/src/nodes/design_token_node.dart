part of 'nodes.dart';

/// Fields shared by every entry in a token document — [Token]s and
/// [Group]s both.
sealed class DesignTokenNode {
  const DesignTokenNode({
    this.description,
    this.deprecation,
    this.extensions,
    this.ownType,
  });

  /// Free-form documentation (§6.1 — `$description`).
  final String? description;

  /// Deprecation marker (§6.3 — `$deprecated`); `null` if the property
  /// was absent on this node.
  final Deprecation? deprecation;

  /// Opaque, vendor-namespaced metadata (§6.2 — `$extensions`); preserved
  /// verbatim and never interpreted.
  final Map<String, Object?>? extensions;

  /// The `$type` string written on THIS node, before any inheritance /
  /// alias-inference pass. Use [TokenResolver.resolveType] to get the
  /// effective type for a token.
  final String? ownType;

  /// Emits the common `$`-properties onto [out] in the canonical order.
  void writeMetaTo(Map<String, Object?> out) {
    final nodeType = ownType;
    if (nodeType != null) out[r'$type'] = nodeType;
    final desc = description;
    if (desc != null) out[r'$description'] = desc;
    final dep = deprecation;
    if (dep != null) out[r'$deprecated'] = dep.toJson();
    final ext = extensions;
    if (ext != null) out[r'$extensions'] = Map<String, Object?>.from(ext);
  }
}
