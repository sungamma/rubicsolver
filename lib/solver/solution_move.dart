import '../cube/cube_face.dart';

/// One face turn in standard Singmaster notation.
///
/// The const constructor keeps move lists usable as compile-time constants for
/// the playback widgets.  It performs a debug assertion for malformed input;
/// callers that need a regular [ArgumentError] should use [parse].
class SolutionMove {
  const SolutionMove(this.notation)
    : assert(
        notation == 'U' ||
            notation == 'U2' ||
            notation == "U'" ||
            notation == 'R' ||
            notation == 'R2' ||
            notation == "R'" ||
            notation == 'F' ||
            notation == 'F2' ||
            notation == "F'" ||
            notation == 'D' ||
            notation == 'D2' ||
            notation == "D'" ||
            notation == 'L' ||
            notation == 'L2' ||
            notation == "L'" ||
            notation == 'B' ||
            notation == 'B2' ||
            notation == "B'",
        'Move must use standard notation such as R, R\', or R2.',
      );

  /// Parses and validates a move, throwing [ArgumentError] for malformed
  /// notation.  This is useful for user-entered algorithms where assertions
  /// may be disabled.
  factory SolutionMove.parse(String notation) {
    if (!_notationPattern.hasMatch(notation)) {
      throw ArgumentError.value(
        notation,
        'notation',
        '动作必须使用标准记号，例如 R、R\' 或 R2',
      );
    }
    return SolutionMove(notation);
  }

  /// Alias for [parse] when constructing from external text.
  factory SolutionMove.fromNotation(String notation) =>
      SolutionMove.parse(notation);

  /// Explicitly checked constructor for non-const/dynamic input.
  factory SolutionMove.checked(String notation) => SolutionMove.parse(notation);

  static final _notationPattern = RegExp(r"^[URFDLB](2|')?$");

  /// Singmaster notation (`R`, `R'`, or `R2`).
  final String notation;

  /// The face affected by this move.
  CubeFace get face {
    // The constructor assertion/parse check guarantees this lookup succeeds.
    return CubeFace.fromLetter(notation[0]);
  }

  /// Number of clockwise quarter-turns represented by this move.
  ///
  /// A prime turn is represented as three clockwise quarter-turns so callers
  /// that replay a move in a loop can use this value directly.  Use
  /// [signedQuarterTurns] when the direction matters.
  int get turns => notation.endsWith('2')
      ? 2
      : notation.endsWith("'")
      ? 3
      : 1;

  /// Signed quarter-turn count (`-1` for a prime turn).
  int get signedQuarterTurns => notation.endsWith('2')
      ? 2
      : notation.endsWith("'")
      ? -1
      : 1;

  /// Alias for [turns] used by animation code.
  int get quarterTurns => turns;

  /// Whether this is a counter-clockwise (prime) turn.
  bool get isInverse => notation.endsWith("'");

  /// Alias for [isInverse].
  bool get isPrime => isInverse;

  /// Whether this is a 180° turn.
  bool get isDouble => notation.endsWith('2');

  /// Alias for [isDouble].
  bool get isHalfTurn => isDouble;

  /// The face letter (`U`, `R`, `F`, `D`, `L`, or `B`).
  String get faceLetter => notation[0];

  /// A short Chinese instruction suitable for the playback view.
  String get instruction {
    final faceName = switch (face) {
      CubeFace.up => '上面',
      CubeFace.right => '右面',
      CubeFace.front => '前面',
      CubeFace.down => '下面',
      CubeFace.left => '左面',
      CubeFace.back => '后面',
    };

    if (isDouble) {
      return '正对$faceName看，转动 180°';
    }
    final direction = isInverse ? '逆时针' : '顺时针';
    return '正对$faceName看，$direction转动 90°';
  }

  /// Alias used by some presentation clients.
  String get description => instruction;

  /// Alias emphasizing that this is localized text.
  String get chineseInstruction => instruction;

  /// Short alias for localized instruction text.
  String get chinese => instruction;

  /// Alias for [instruction] used by list/card views.
  String get label => instruction;

  /// Returns the inverse move while preserving standard notation.
  SolutionMove inverse() {
    if (isDouble) {
      return this;
    }
    return SolutionMove(isInverse ? notation.substring(0, 1) : '$notation\'');
  }

  /// Standard notation for the inverse move.
  String get inverseNotation => inverse().notation;

  /// Convenience object form of [inverse].
  SolutionMove get inverseMove => inverse();

  @override
  String toString() => notation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolutionMove && other.notation == notation;

  @override
  int get hashCode => notation.hashCode;
}
