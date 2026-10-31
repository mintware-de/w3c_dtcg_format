part of 'values.dart';

const _transitionFields = <String>{'duration', 'delay', 'timingFunction'};

/// A `transition` token value (§9.5).
final class TransitionValue extends TokenValue {
  const TransitionValue({
    required this.duration,
    required this.delay,
    required this.timingFunction,
  });

  /// Transition duration: a [DurationValue] or a reference.
  final TokenValue duration;

  /// Delay before the transition starts: a [DurationValue] or a reference.
  final TokenValue delay;

  /// Easing curve: a [CubicBezierValue] or a reference.
  final TokenValue timingFunction;

  @override
  Object toJson() => <String, Object?>{
    'duration': duration.toJson(),
    'delay': delay.toJson(),
    'timingFunction': timingFunction.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitionValue &&
          other.duration == duration &&
          other.delay == delay &&
          other.timingFunction == timingFunction;

  @override
  int get hashCode => Object.hash(duration, delay, timingFunction);

  @override
  String toString() =>
      'TransitionValue(duration=$duration, delay=$delay, '
      'timingFunction=$timingFunction)';

  /// Parses a `$value` as a [TransitionValue].
  static TokenValue? parse(Object? raw, ErrorCollector errors) {
    if (raw is! Map) {
      errors.error(
        IssueCode.valueWrongShape,
        'transition value must be a JSON object',
      );
      return null;
    }
    _warnExtraFields(raw, _transitionFields, errors);

    final duration = _parseCompositeField(
      raw,
      'duration',
      DurationValue.parse,
      errors,
    );
    final delay = _parseCompositeField(
      raw,
      'delay',
      DurationValue.parse,
      errors,
    );
    final timingFunction = _parseCompositeField(
      raw,
      'timingFunction',
      CubicBezierValue.parse,
      errors,
    );
    if (duration == null || delay == null || timingFunction == null) {
      return null;
    }
    return TransitionValue(
      duration: duration,
      delay: delay,
      timingFunction: timingFunction,
    );
  }
}
