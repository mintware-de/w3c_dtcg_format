/// Pre-visit transform hook — a sanctioned way to normalize non-conformant
/// documents into spec-conformant shape on the way into [parseDocument] /
/// [parseDocumentString].
library;

/// Transformer called for every JSON object the parser is about to turn
/// into a [Group] or [Token].
///
/// Receives the raw JSON (as produced by `jsonDecode`) and the surrounding
/// [NodeVisitContext], and returns a (possibly modified) JSON object that
/// the strict parser then consumes. Return `raw` unchanged for a no-op.
///
/// Runs BEFORE:
///   * `$type` resolution and inheritance,
///   * `$value` parsing,
///   * composite sub-field parsing of this node's `$value`.
///
/// Does NOT run on composite sub-fields themselves (border.color,
/// shadow.offsetX, …) because those aren't nodes — they're [TokenValue]s
/// inside a `$value`. To change those, rewrite the enclosing token's
/// `$value` map from this hook.
///
/// Exceptions thrown by the visitor are not caught; they propagate out of
/// `parseDocument`.
typedef NodePreVisitor = Map<String, Object?> Function(
  NodeVisitContext context,
  Map<String, Object?> raw,
);

/// What the visitor knows about where it is in the document.
final class NodeVisitContext {
  const NodeVisitContext({
    required this.jsonPointer,
    required this.segments,
    required this.inheritedType,
    required this.isRoot,
  });

  /// RFC 6901 pointer from the document root to this node (`""` at root).
  final String jsonPointer;

  /// Unescaped segment list making up [jsonPointer]. Empty at the root.
  final List<String> segments;

  /// The `$type` inherited from this node's lexical ancestors. The node's
  /// OWN `$type` has not been read yet, so this is strictly inherited.
  /// `null` when no ancestor set one.
  final String? inheritedType;

  /// True iff this is the document root.
  final bool isRoot;

  @override
  String toString() =>
      'NodeVisitContext($jsonPointer, inheritedType=$inheritedType'
      '${isRoot ? ', root' : ''})';
}
