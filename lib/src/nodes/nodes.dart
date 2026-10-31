/// Sealed [DesignTokenNode] hierarchy (`Token | Group`) plus [Deprecated].
///
/// All concrete types live in `part` files that share this library.
library;

import '../values/values.dart';

part 'deprecated.dart';
part 'design_token_node.dart';
part 'group.dart';
part 'token.dart';
