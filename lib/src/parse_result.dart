import 'document.dart';
import 'validation/issue.dart';

/// The result of a single parse.
///
/// [document] is non-null when the parser could produce a tree; some
/// tokens inside it may still carry [IssueSeverity.error]-level issues
/// in [issues] (for example, individual tokens with unparseable
/// `$value`s are elided and recorded, but the rest of the document
/// is kept). The only shape that forces a null document is a non-object
/// root (there is nothing to walk).
final class ParseResult {
  const ParseResult({required this.document, required this.issues});

  final DesignTokenDocument? document;
  final List<ValidationIssue> issues;

  /// Whether any issue is severity [IssueSeverity.error].
  bool get hasErrors => issues.any((i) => i.severity == IssueSeverity.error);

  /// Shorthand for the inverse of [hasErrors].
  bool get isValid => !hasErrors;

  @override
  String toString() =>
      'ParseResult('
      '${document == null ? "no document" : "ok"}, '
      '${issues.length} issue${issues.length == 1 ? "" : "s"})';
}
