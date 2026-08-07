/// A normalized semantic app version with an optional Flutter build number.
class VersionNumber implements Comparable<VersionNumber> {
  const VersionNumber({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  /// Parses `major.minor[.patch][+build]` (an optional leading `v` is
  /// accepted).  Malformed remote metadata is rejected with a
  /// [FormatException] so an update check can fail silently.
  factory VersionNumber.parse(String value) {
    final normalized = value.trim();
    final match = _pattern.firstMatch(normalized);
    if (match == null) {
      throw FormatException('无效的版本号：$value');
    }

    int parsePart(String? part) => int.parse(part ?? '0');
    try {
      return VersionNumber(
        major: parsePart(match.group(1)),
        minor: parsePart(match.group(2)),
        patch: parsePart(match.group(3)),
        build: parsePart(match.group(4)),
      );
    } on FormatException {
      throw FormatException('无效的版本号：$value');
    }
  }

  /// Parses a version, returning `null` instead of throwing.
  static VersionNumber? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    try {
      return VersionNumber.parse(value);
    } on FormatException {
      return null;
    }
  }

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:\+(\d+))?$',
    caseSensitive: false,
  );

  final int major;
  final int minor;
  final int patch;
  final int build;

  @override
  int compareTo(VersionNumber other) {
    final semantic = _compareParts(major, other.major);
    if (semantic != 0) return semantic;
    final minorResult = _compareParts(minor, other.minor);
    if (minorResult != 0) return minorResult;
    final patchResult = _compareParts(patch, other.patch);
    if (patchResult != 0) return patchResult;
    return _compareParts(build, other.build);
  }

  static int _compareParts(int left, int right) =>
      left < right ? -1 : (left > right ? 1 : 0);

  bool operator >(VersionNumber other) => compareTo(other) > 0;

  bool operator >=(VersionNumber other) => compareTo(other) >= 0;

  bool operator <(VersionNumber other) => compareTo(other) < 0;

  bool operator <=(VersionNumber other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is VersionNumber &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch &&
      build == other.build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$major.$minor.$patch+$build';
}
