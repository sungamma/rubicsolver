import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/update/version_number.dart';

void main() {
  test('compares semantic version and Flutter build number', () {
    expect(
      VersionNumber.parse('1.2.0+4') > VersionNumber.parse('1.1.9+99'),
      isTrue,
    );
    expect(
      VersionNumber.parse('1.2.0+4') > VersionNumber.parse('1.2.0+3'),
      isTrue,
    );
    expect(
      VersionNumber.parse('1.2.0') == VersionNumber.parse('1.2.0+0'),
      isTrue,
    );
  });

  test('accepts a leading v and normalizes missing components', () {
    final version = VersionNumber.parse('v2.4');

    expect(version.major, 2);
    expect(version.minor, 4);
    expect(version.patch, 0);
    expect(version.build, 0);
    expect(version.toString(), '2.4.0+0');
  });

  test('rejects malformed or negative versions', () {
    for (final value in ['1', '1..2', '1.2.-1', 'one.2.3', '']) {
      expect(() => VersionNumber.parse(value), throwsFormatException);
    }
  });

  test('supports sorting and value equality', () {
    final versions = [
      VersionNumber.parse('1.0.0+1'),
      VersionNumber.parse('1.0.0+0'),
      VersionNumber.parse('0.9.9+99'),
    ]..sort();

    expect(versions.map((version) => version.toString()).toList(), [
      '0.9.9+99',
      '1.0.0+0',
      '1.0.0+1',
    ]);
    expect(VersionNumber.parse('1.2.0'), VersionNumber.parse('1.2.0+0'));
  });
}
