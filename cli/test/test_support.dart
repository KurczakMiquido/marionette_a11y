import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

String fixturePath(String name) => File('test/fixtures/$name.json').absolute.path;

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File(fixturePath(name)).readAsStringSync()) as Map<String, dynamic>;

/// A temporary probes directory whose `<platform>/run.sh` runs [body]. The script records its arguments in
/// `args.txt` next to itself. Deleted after the test.
Future<Directory> fakeProbes(String body, {String platform = 'android'}) async {
  final dir = await Directory.systemTemp.createTemp('a11y_probes_');
  addTearDown(() => dir.delete(recursive: true));
  final script = File('${dir.path}/$platform/run.sh');
  await script.create(recursive: true);
  await script.writeAsString('#!/usr/bin/env bash\nprintf "%s\\n" "\$@" > "\$(dirname "\$0")/args.txt"\n$body\n');
  await Process.run('chmod', ['+x', script.path]);
  return dir;
}

/// A probe that writes the given fixture as its output.
Future<Directory> fixtureProbes(String name, {String platform = 'android'}) =>
    fakeProbes('cp "${fixturePath(name)}" "\$3"', platform: platform);

List<String> recordedArgs(Directory probes, {String platform = 'android'}) =>
    File('${probes.path}/$platform/args.txt').readAsLinesSync();

/// Starts `fake_app.dart` and returns its VM service WebSocket URI. Killed after the test.
Future<String> startFakeApp({bool withExtension = true, bool hangAudit = false}) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'test/fixtures/fake_app.dart',
    fixturePath('flutter_snapshot'),
    fixturePath('flutter_audit'),
    if (!withExtension) '--no-extension',
    if (hangAudit) '--hang-audit',
  ]);
  addTearDown(() async {
    process.kill();
    await process.exitCode;
  });
  process.stderr.transform(utf8.decoder).listen(stderr.write);
  return process.stdout.transform(utf8.decoder).transform(const LineSplitter()).first;
}
