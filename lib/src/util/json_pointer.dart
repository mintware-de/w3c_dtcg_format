/// Minimal RFC 6901 JSON Pointer helpers.
///
/// A pointer is a string of `/`-separated reference tokens. Inside each
/// token `~0` decodes to `~` and `~1` decodes to `/`. The empty string
/// refers to the whole document.
library;

/// Parses [pointer] into its list of unescaped reference tokens.
///
/// Returns `null` when [pointer] is malformed. Returns an empty list for
/// the whole-document pointer (`""`).
List<String>? parseJsonPointer(String pointer) {
  if (pointer.isEmpty) return const <String>[];
  if (!pointer.startsWith('/')) return null;
  final raw = pointer.substring(1).split('/');
  final out = <String>[];
  for (final token in raw) {
    final decoded = _decodeToken(token);
    if (decoded == null) return null;
    out.add(decoded);
  }
  return out;
}

/// Encodes [tokens] back into an RFC 6901 pointer string.
String encodeJsonPointer(Iterable<String> tokens) {
  final buffer = StringBuffer();
  for (final token in tokens) {
    buffer.write('/');
    buffer.write(_encodeToken(token));
  }
  return buffer.toString();
}

/// Walks [root] following [pointer]. Returns the pointed-at value, or `null`
/// if the pointer is malformed or does not resolve.
///
/// Numeric tokens are interpreted as list indices when the parent is a
/// `List`; a leading `0` for a non-zero index is rejected per the RFC.
Object? applyJsonPointer(Object? root, String pointer) {
  final tokens = parseJsonPointer(pointer);
  if (tokens == null) return null;
  Object? current = root;
  for (final token in tokens) {
    if (current is Map) {
      if (!current.containsKey(token)) return null;
      current = current[token];
    } else if (current is List) {
      final index = _listIndex(token, current.length);
      if (index == null) return null;
      current = current[index];
    } else {
      return null;
    }
  }
  return current;
}

String _encodeToken(String token) =>
    token.replaceAll('~', '~0').replaceAll('/', '~1');

String? _decodeToken(String token) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < token.length) {
    final ch = token.codeUnitAt(i);
    if (ch == 0x7E) {
      if (i + 1 >= token.length) return null;
      final next = token.codeUnitAt(i + 1);
      if (next == 0x30) {
        buffer.writeCharCode(0x7E);
      } else if (next == 0x31) {
        buffer.writeCharCode(0x2F);
      } else {
        return null;
      }
      i += 2;
    } else {
      buffer.writeCharCode(ch);
      i++;
    }
  }
  return buffer.toString();
}

int? _listIndex(String token, int length) {
  if (token.isEmpty) return null;
  if (token.length > 1 && token.startsWith('0')) return null;
  final value = int.tryParse(token);
  if (value == null || value < 0 || value >= length) return null;
  return value;
}
