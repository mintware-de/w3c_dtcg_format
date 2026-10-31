part of 'nodes.dart';

/// A parsed `$deprecated` property.
///
/// `$deprecated` is either a boolean or a string (an explanation). An
/// absent property is represented by the enclosing [DesignTokenNode]
/// carrying `null` for its [DesignTokenNode.deprecation] field.
///
/// Named [Deprecation] rather than `Deprecated` to avoid colliding with
/// `dart:core`'s annotation class of that name.
sealed class Deprecation {
  const Deprecation();

  /// `$deprecated: true` or `$deprecated: false`.
  const factory Deprecation.flag(bool deprecated) = DeprecationFlag;

  /// `$deprecated: "<explanation>"`. Implies `true`.
  const factory Deprecation.reason(String reason) = DeprecationReason;

  /// `true` iff this value marks the node as deprecated.
  bool get isDeprecated => switch (this) {
    DeprecationFlag(:final deprecated) => deprecated,
    DeprecationReason() => true,
  };

  Object toJson();
}

/// `$deprecated: true` or `$deprecated: false`.
final class DeprecationFlag extends Deprecation {
  const DeprecationFlag(this.deprecated);
  final bool deprecated;

  @override
  Object toJson() => deprecated;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeprecationFlag && other.deprecated == deprecated;

  @override
  int get hashCode => deprecated.hashCode;

  @override
  String toString() => 'Deprecation($deprecated)';
}

/// `$deprecated: "<explanation>"`.
final class DeprecationReason extends Deprecation {
  const DeprecationReason(this.reason);
  final String reason;

  @override
  Object toJson() => reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeprecationReason && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'Deprecation("$reason")';
}
