import '../document.dart';
import '../nodes/nodes.dart';
import '../util/json_pointer.dart';
import '../validation/error_collector.dart';
import '../validation/issue.dart';
import '../values/values.dart';

/// Walks a [DesignTokenDocument] to resolve aliases, `$ref` pointers,
/// inherited `$type`, and `$extends` chains.
///
/// The resolver is read-only; it never mutates the document. All operations
/// detect cycles with a visited-set. The default [maxDepth] (`64`) is well
/// beyond realistic token graphs — if you hit it, there's almost certainly
/// a cycle the resolver did not catch.
final class TokenResolver {
  TokenResolver(this.document) {
    _buildIndex(document.root, const <DesignTokenNode>[], const <String>[]);
  }

  final DesignTokenDocument document;

  final Map<DesignTokenNode, List<DesignTokenNode>> _ancestors =
      Map<DesignTokenNode, List<DesignTokenNode>>.identity();
  final Map<DesignTokenNode, List<String>> _pathSegments =
      Map<DesignTokenNode, List<String>>.identity();

  void _buildIndex(
    DesignTokenNode node,
    List<DesignTokenNode> ancestors,
    List<String> segments,
  ) {
    _ancestors[node] = List<DesignTokenNode>.unmodifiable(ancestors);
    _pathSegments[node] = List<String>.unmodifiable(segments);
    if (node is Group) {
      for (final entry in node.children.entries) {
        _buildIndex(
          entry.value,
          <DesignTokenNode>[...ancestors, node],
          <String>[...segments, entry.key],
        );
      }
    }
  }

  /// The path segments from the root to [node], or `null` if [node] is not
  /// part of this document.
  List<String>? pathSegmentsOf(DesignTokenNode node) => _pathSegments[node];

  // ---- alias / ref lookup ------------------------------------------------

  /// Looks up a brace-syntax reference's target. Returns `null` if any
  /// segment is missing or lands on a non-group before the end.
  DesignTokenNode? lookupBracePath(String bracePath) =>
      document.lookupBracePath(bracePath);

  /// Resolves a brace alias to its target token's `$value`. Returns `null`
  /// if the path does not resolve to a token.
  TokenValue? resolveAlias(String bracePath) {
    final node = lookupBracePath(bracePath);
    if (node is Token) return node.value;
    return null;
  }

  /// Resolves a `$ref` JSON Pointer against the serialized form of the
  /// document and returns the raw JSON at that location. `$ref` can land
  /// anywhere, including inside a composite sub-value, so a typed result is
  /// not always meaningful — the raw form is faithful.
  Object? resolveRefRaw(String pointer) =>
      applyJsonPointer(document.toJson(), pointer);

  // ---- $type -------------------------------------------------------------

  /// Resolves the effective `$type` for [node] as a [TokenType] enum, or
  /// `null` when unknown.
  TokenType? resolveType(DesignTokenNode node) {
    final name = resolveTypeName(node);
    if (name == null) return null;
    return TokenType.byName(name);
  }

  /// Resolves the effective `$type` wire string for [node], walking:
  /// own → nearest ancestor group's `$type` → aliased target's resolved
  /// `$type` (recursive, with cycle guard).
  String? resolveTypeName(DesignTokenNode node) =>
      _resolveTypeName(node, Set<DesignTokenNode>.identity());

  String? _resolveTypeName(DesignTokenNode node, Set<DesignTokenNode> visited) {
    if (!visited.add(node)) return null;
    if (node.ownType != null) return node.ownType;
    final ancestors = _ancestors[node] ?? const <DesignTokenNode>[];
    for (var i = ancestors.length - 1; i >= 0; i--) {
      final inherited = ancestors[i].ownType;
      if (inherited != null) return inherited;
    }
    if (node is Token) {
      final target = _followOneHop(node.value);
      if (target != null) return _resolveTypeName(target, visited);
    }
    return null;
  }

  /// Follows a single reference hop to its target node, when the hop
  /// resolves to a token. Returns `null` otherwise.
  DesignTokenNode? _followOneHop(TokenValue value) {
    if (value is AliasValue) return lookupBracePath(value.path);
    if (value is RefValue) {
      final tokens = parseJsonPointer(value.pointer);
      if (tokens == null) return null;
      // Walk the structural tree segment-by-segment. `$value` and beyond
      // means we are inside a value, not pointing at a node.
      DesignTokenNode current = document.root;
      for (var i = 0; i < tokens.length; i++) {
        final seg = tokens[i];
        if (seg == r'$value' && i == tokens.length - 1 && current is Token) {
          // The pointer ends at a token's $value — same as pointing at the
          // token itself for type-inference purposes.
          return current;
        }
        if (current is! Group) return null;
        final child = current.children[seg];
        if (child == null) return null;
        current = child;
      }
      return current;
    }
    return null;
  }

  // ---- $extends ----------------------------------------------------------

  /// Resolves a group's `$extends` pointer to the inherited group.
  /// Returns `null` on cycle, missing target, or a target that is not a
  /// group.
  Group? resolveExtends(Group group) {
    final target = _followExtendsOnce(group);
    if (target is Group && !identical(target, group)) return target;
    return null;
  }

  DesignTokenNode? _followExtendsOnce(Group group) {
    final ref = group.extendsRef;
    if (ref == null) return null;
    final tokens = parseJsonPointer(ref);
    if (tokens == null) return null;
    DesignTokenNode current = document.root;
    for (final seg in tokens) {
      if (current is! Group) return null;
      final child = current.children[seg];
      if (child == null) return null;
      current = child;
    }
    return current;
  }

  // ---- full resolution ---------------------------------------------------

  /// Follows alias chains fully and recursively resolves composite
  /// sub-fields, returning a value that contains no [AliasValue]s on paths
  /// that resolve.
  ///
  /// References that fail to resolve (dangling, cyclic, or `$ref` landing
  /// inside a composite) are returned as-is at the position they occur, so
  /// the caller can tell what did not resolve. `$ref` resolution does not
  /// substitute values — use [resolveRefRaw] for that.
  TokenValue resolveFully(TokenValue value, {int maxDepth = 64}) =>
      _resolveFully(value, maxDepth, <String>{});

  TokenValue _resolveFully(
    TokenValue value,
    int depth,
    Set<String> aliasChain,
  ) {
    if (depth <= 0) return value;
    TokenValue current = value;
    var remaining = depth;
    while (current is AliasValue) {
      if (!aliasChain.add(current.path)) return current;
      final target = resolveAlias(current.path);
      if (target == null) return current;
      current = target;
      remaining--;
      if (remaining <= 0) return current;
    }
    if (current is RefValue) return current;
    return _resolveComposite(current, remaining, aliasChain);
  }

  TokenValue _resolveComposite(
    TokenValue value,
    int depth,
    Set<String> aliasChain,
  ) {
    Set<String> fresh() => <String>{...aliasChain};
    return switch (value) {
      final BorderValue b => BorderValue(
        color: _resolveFully(b.color, depth, fresh()),
        width: _resolveFully(b.width, depth, fresh()),
        style: _resolveFully(b.style, depth, fresh()),
      ),
      final TransitionValue t => TransitionValue(
        duration: _resolveFully(t.duration, depth, fresh()),
        delay: _resolveFully(t.delay, depth, fresh()),
        timingFunction: _resolveFully(t.timingFunction, depth, fresh()),
      ),
      final TypographyValue t => TypographyValue(
        fontFamily: _resolveFully(t.fontFamily, depth, fresh()),
        fontSize: _resolveFully(t.fontSize, depth, fresh()),
        fontWeight: _resolveFully(t.fontWeight, depth, fresh()),
        letterSpacing: _resolveFully(t.letterSpacing, depth, fresh()),
        lineHeight: _resolveFully(t.lineHeight, depth, fresh()),
      ),
      final SingleShadow s => ShadowValue.single(
        ShadowObject(
          color: _resolveFully(s.shadow.color, depth, fresh()),
          offsetX: _resolveFully(s.shadow.offsetX, depth, fresh()),
          offsetY: _resolveFully(s.shadow.offsetY, depth, fresh()),
          blur: _resolveFully(s.shadow.blur, depth, fresh()),
          spread: _resolveFully(s.shadow.spread, depth, fresh()),
          inset: s.shadow.inset,
        ),
      ),
      final ListShadow l => ShadowValue.list(<TokenValue>[
        for (final e in l.entries) _resolveFully(e, depth, fresh()),
      ]),
      final ObjectStrokeStyle s => StrokeStyleValue.object(
        dashArray: <TokenValue>[
          for (final d in s.dashArray) _resolveFully(d, depth, fresh()),
        ],
        lineCap: s.lineCap,
      ),
      final GradientValue g => GradientValue(<TokenValue>[
        for (final s in g.stops) _resolveFully(s, depth, fresh()),
      ]),
      final GradientStopValue gs => GradientStopValue(
        GradientStop(
          color: _resolveFully(gs.stop.color, depth, fresh()),
          position: _resolveFully(gs.stop.position, depth, fresh()),
        ),
      ),
      _ => value,
    };
  }

  // ---- cross-cutting validation -----------------------------------------

  /// Walks every token and group reporting unresolved aliases, missing
  /// `$ref` targets, cyclic alias chains, `$extends` cycles, `$extends`
  /// targets that are tokens or missing, and tokens whose `$type` cannot
  /// be determined after inheritance and alias following.
  ///
  /// Each returned issue carries the RFC 6901 JSON Pointer of the
  /// offending location.
  List<ValidationIssue> validateReferences() {
    final errors = ErrorCollector();
    for (final entry in document.walk()) {
      final node = entry.node;
      final path = entry.path;
      if (node is Group) {
        _validateExtends(node, path, errors);
      } else if (node is Token) {
        _validateTokenValue(node, path, errors);
      }
    }
    return errors.issues;
  }

  void _validateExtends(Group group, String groupPath, ErrorCollector errors) {
    final ref = group.extendsRef;
    if (ref == null) return;
    final visited = Set<DesignTokenNode>.identity()..add(group);
    Group current = group;
    while (true) {
      final target = _followExtendsOnce(current);
      if (target == null) {
        errors.at(
          '$groupPath/\$extends',
          IssueCode.extendsNotFound,
          IssueSeverity.error,
          '\$extends target "${current.extendsRef}" does not resolve',
        );
        return;
      }
      if (target is Token) {
        errors.at(
          '$groupPath/\$extends',
          IssueCode.extendsTargetsToken,
          IssueSeverity.error,
          '\$extends must target a group, not a token',
        );
        return;
      }
      if (!visited.add(target)) {
        errors.at(
          '$groupPath/\$extends',
          IssueCode.extendsCycle,
          IssueSeverity.error,
          '\$extends chain forms a cycle',
          details: <String>[
            for (final n in visited) _pathSegments[n]?.join('.') ?? '<?>',
          ],
        );
        return;
      }
      final nextGroup = target as Group;
      if (nextGroup.extendsRef == null) return;
      current = nextGroup;
    }
  }

  void _validateTokenValue(
    Token token,
    String tokenPath,
    ErrorCollector errors,
  ) {
    _validateValue(token.value, '$tokenPath/\$value', errors, <String>{});
    // Also assert the token has a resolvable $type.
    final typeName = resolveTypeName(token);
    if (typeName == null) {
      errors.at(
        tokenPath,
        IssueCode.missingType,
        IssueSeverity.error,
        'token has no resolvable \$type after inheritance and alias follow',
      );
    }
  }

  void _validateValue(
    TokenValue value,
    String path,
    ErrorCollector errors,
    Set<String> aliasChain,
  ) {
    if (value is AliasValue) {
      if (!aliasChain.add(value.path)) {
        errors.at(
          path,
          IssueCode.aliasCycle,
          IssueSeverity.error,
          'alias chain forms a cycle',
          details: List<String>.unmodifiable(aliasChain),
        );
        return;
      }
      final target = lookupBracePath(value.path);
      if (target == null) {
        errors.at(
          path,
          IssueCode.aliasNotFound,
          IssueSeverity.error,
          'alias target "{${value.path}}" does not resolve',
        );
        return;
      }
      if (target is Token) {
        _validateValue(target.value, path, errors, aliasChain);
      }
      return;
    }
    if (value is RefValue) {
      final raw = resolveRefRaw(value.pointer);
      if (raw == null) {
        errors.at(
          path,
          IssueCode.refNotFound,
          IssueSeverity.error,
          '\$ref target "${value.pointer}" does not resolve',
        );
      }
      return;
    }
    for (final sub in _compositeSubValues(value)) {
      _validateValue(sub.value, '$path/${sub.segment}', errors, aliasChain);
    }
  }
}

/// The inline sub-TokenValues of a composite, each with the path segment
/// to append when descending into it.
///
/// Returns an empty iterable for primitive concrete values and for any
/// reference ([AliasValue], [RefValue]) — references have no sub-tree in
/// the structural sense, since they resolve against the index.
Iterable<({String segment, TokenValue value})> _compositeSubValues(
  TokenValue v,
) {
  switch (v) {
    case final BorderValue b:
      return [
        (segment: 'color', value: b.color),
        (segment: 'width', value: b.width),
        (segment: 'style', value: b.style),
      ];
    case final TransitionValue t:
      return [
        (segment: 'duration', value: t.duration),
        (segment: 'delay', value: t.delay),
        (segment: 'timingFunction', value: t.timingFunction),
      ];
    case final TypographyValue t:
      return [
        (segment: 'fontFamily', value: t.fontFamily),
        (segment: 'fontSize', value: t.fontSize),
        (segment: 'fontWeight', value: t.fontWeight),
        (segment: 'letterSpacing', value: t.letterSpacing),
        (segment: 'lineHeight', value: t.lineHeight),
      ];
    case final SingleShadow s:
      return [
        (segment: 'color', value: s.shadow.color),
        (segment: 'offsetX', value: s.shadow.offsetX),
        (segment: 'offsetY', value: s.shadow.offsetY),
        (segment: 'blur', value: s.shadow.blur),
        (segment: 'spread', value: s.shadow.spread),
      ];
    case final ListShadow l:
      return [
        for (var i = 0; i < l.entries.length; i++)
          (segment: '$i', value: l.entries[i]),
      ];
    case final ObjectStrokeStyle s:
      return [
        for (var i = 0; i < s.dashArray.length; i++)
          (segment: 'dashArray/$i', value: s.dashArray[i]),
      ];
    case final GradientValue g:
      return [
        for (var i = 0; i < g.stops.length; i++)
          (segment: '$i', value: g.stops[i]),
      ];
    case final GradientStopValue gs:
      return [
        (segment: 'color', value: gs.stop.color),
        (segment: 'position', value: gs.stop.position),
      ];
    default:
      return const [];
  }
}
