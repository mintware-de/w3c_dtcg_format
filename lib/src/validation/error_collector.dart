import 'issue.dart';

/// Path-aware mutable collector of [ValidationIssue]s.
///
/// A single [ErrorCollector] is threaded through every parsing pass. Callers
/// push and pop path segments as they descend into the JSON tree; each
/// [error] / [warning] stamps the current path onto the issue.
///
/// Paths are RFC 6901 JSON Pointers rooted at `""` (the document root).
final class ErrorCollector {
  ErrorCollector();

  final List<ValidationIssue> _issues = <ValidationIssue>[];
  final List<String> _segments = <String>[];

  /// Snapshot of the issues collected so far.
  List<ValidationIssue> get issues =>
      List<ValidationIssue>.unmodifiable(_issues);

  /// The current JSON Pointer. Empty string for the root.
  String get currentPath {
    if (_segments.isEmpty) return '';
    final buffer = StringBuffer();
    for (final segment in _segments) {
      buffer.write('/');
      buffer.write(_encode(segment));
    }
    return buffer.toString();
  }

  /// Pushes [segment] onto the path and runs [body], then pops it. Returns
  /// whatever [body] returns.
  T withSegment<T>(String segment, T Function() body) {
    _segments.add(segment);
    try {
      return body();
    } finally {
      _segments.removeLast();
    }
  }

  /// Records an error at the current path.
  void error(IssueCode code, String message, {Object? details}) {
    _issues.add(
      ValidationIssue(
        path: currentPath,
        code: code,
        severity: IssueSeverity.error,
        message: message,
        details: details,
      ),
    );
  }

  /// Records a warning at the current path.
  void warning(IssueCode code, String message, {Object? details}) {
    _issues.add(
      ValidationIssue(
        path: currentPath,
        code: code,
        severity: IssueSeverity.warning,
        message: message,
        details: details,
      ),
    );
  }

  /// Records an error one segment below the current path.
  ///
  /// Equivalent to `withSegment(segment, () => error(...))` but without the
  /// closure boilerplate.
  void errorAt(
    String segment,
    IssueCode code,
    String message, {
    Object? details,
  }) => withSegment(segment, () => error(code, message, details: details));

  /// Records a warning one segment below the current path.
  void warningAt(
    String segment,
    IssueCode code,
    String message, {
    Object? details,
  }) => withSegment(segment, () => warning(code, message, details: details));

  /// Records an issue at an explicit path (bypasses the current segments).
  void at(
    String path,
    IssueCode code,
    IssueSeverity severity,
    String message, {
    Object? details,
  }) {
    _issues.add(
      ValidationIssue(
        path: path,
        code: code,
        severity: severity,
        message: message,
        details: details,
      ),
    );
  }

  /// RFC 6901 token encoding: `~` → `~0`, `/` → `~1`.
  static String _encode(String token) =>
      token.replaceAll('~', '~0').replaceAll('/', '~1');
}
