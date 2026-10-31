/// Checks a token or group name against the W3C DTCG rules in §5.1.1:
///
/// * MUST NOT begin with `$`.
/// * MUST NOT contain `{`, `}`, or `.`.
/// * MUST be a non-empty JSON string.
///
/// Returns `null` when the name is valid, or a short human-readable reason
/// when it is not. Case-insensitive collisions between siblings are a
/// separate concern (see [IssueCode.caseInsensitiveNameCollision]).
String? validateName(String name) {
  if (name.isEmpty) return 'name must not be empty';
  if (name.startsWith(r'$')) return r'name must not start with "$"';
  for (var i = 0; i < name.length; i++) {
    final codeUnit = name.codeUnitAt(i);
    if (codeUnit == 0x7B) return 'name must not contain "{"';
    if (codeUnit == 0x7D) return 'name must not contain "}"';
    if (codeUnit == 0x2E) return 'name must not contain "."';
  }
  return null;
}

/// `$`-prefixed properties the spec defines on tokens and/or groups.
///
/// Any other `$`-key encountered is reported as
/// [IssueCode.unknownDollarProperty].
const Set<String> knownDollarProperties = <String>{
  r'$value',
  r'$type',
  r'$description',
  r'$extensions',
  r'$deprecated',
  r'$extends',
};
