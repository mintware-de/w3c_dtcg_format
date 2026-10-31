import 'dart:convert';

import 'nodes/nodes.dart';
import 'util/json_pointer.dart';

/// A parsed design-token document.
///
/// The root of the file is treated as an implicit [Group] per §5.1.
final class DesignTokenDocument {
  const DesignTokenDocument(this.root);

  /// The implicit root group.
  final Group root;

  /// Returns the JSON object this document round-trips to.
  Map<String, Object?> toJson() => root.toJson();

  /// Serializes to a JSON string. [indent] controls pretty-printing (two
  /// spaces per level when `true`).
  String encode({bool indent = true}) {
    final encoder = indent
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    return encoder.convert(toJson());
  }

  /// Depth-first walk yielding every node (including the root) with its
  /// RFC 6901 JSON Pointer path. The root yields with path `""`.
  Iterable<DocumentEntry> walk() sync* {
    yield* _walk(root, const <String>[]);
  }

  Iterable<DocumentEntry> _walk(DesignTokenNode node, List<String> path) sync* {
    yield DocumentEntry(encodeJsonPointer(path), path, node);
    if (node is Group) {
      for (final entry in node.children.entries) {
        yield* _walk(entry.value, [...path, entry.key]);
      }
    }
  }

  /// Looks up a node by its brace-syntax path (e.g. `"color.accent"`).
  /// Returns `null` if any segment is missing or lands on a non-group
  /// before the end.
  DesignTokenNode? lookupBracePath(String bracePath) {
    if (bracePath.isEmpty) return root;
    DesignTokenNode current = root;
    for (final segment in bracePath.split('.')) {
      if (current is! Group) return null;
      final child = current.children[segment];
      if (child == null) return null;
      current = child;
    }
    return current;
  }
}

/// A node plus its position in the document, yielded by
/// [DesignTokenDocument.walk].
final class DocumentEntry {
  const DocumentEntry(this.path, this.segments, this.node);

  /// RFC 6901 JSON Pointer path (`""` for the root).
  final String path;

  /// The individual (unescaped) segments making up [path].
  final List<String> segments;

  final DesignTokenNode node;

  /// The dot-separated path a brace reference would use (`""` for the
  /// root). Note that segments containing `.` are not escaped — such
  /// names are invalid per §5.1.1 and would have been rejected at parse.
  String get bracePath => segments.join('.');

  @override
  String toString() => 'DocumentEntry($path, $node)';
}
