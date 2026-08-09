import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deploy script publishes a project-specific Android release', () {
    final script = File('deploy.bat').readAsStringSync();

    expect(script, contains('set "projectName=rubicsolver"'));
    expect(script, contains('set "publishDir=X:\\certificate"'));
    expect(
      script,
      contains('set "updateNotesDest=rubicsolver_update_notes.md"'),
    );
    expect(script, contains('findstr /r /c:"^version:" pubspec.yaml'));
    expect(script, contains('set "buildNumber=%%a"'));
    expect(script, contains('deploy_flutter_app.bat'));
    expect(script, isNot(contains('flutter build')));
  });
}
