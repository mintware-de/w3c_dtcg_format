/// A Dart parser, validator, resolver and serializer for the W3C
/// Design Tokens Community Group *Format Module*, revision 2025.10
/// (plus the companion Color Module).
///
/// Typical usage:
///
/// ```dart
/// import 'package:w3c_dtcg_format/w3c_dtcg_format.dart';
///
/// final result = parseDocumentString(json);
/// if (!result.isValid) {
///   for (final issue in result.issues) print(issue);
///   return;
/// }
/// final doc = result.document!;
/// final resolver = TokenResolver(doc);
/// ```
library;

export 'src/document.dart';
export 'src/nodes/nodes.dart';
export 'src/parse_result.dart';
export 'src/parsing/parser.dart';
export 'src/parsing/visitor.dart';
export 'src/resolver/resolver.dart';
export 'src/validation/issue.dart';
export 'src/values/values.dart';
