import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// A temporary executable [name] that runs [body] and records its arguments in `<name>.args` next to itself.
/// Returns its path. Deleted after the test.
Future<String> fakeTool(String name, String body) async {
  final dir = await Directory.systemTemp.createTemp('a11y_tool_');
  addTearDown(() => dir.delete(recursive: true));
  final script = File('${dir.path}/$name');
  await script.writeAsString('#!/usr/bin/env bash\nprintf "%s\\n" "\$@" > "\$0.args"\n$body\n');
  await Process.run('chmod', ['+x', script.path]);
  return script.path;
}

/// The arguments the [fakeTool] at [path] was last called with; null when it never ran.
List<String>? toolArgs(String path) {
  final file = File('$path.args');
  return file.existsSync() ? file.readAsLinesSync() : null;
}

/// The start of a PNG: signature and an IHDR chunk with [width] and [height]. Enough for the size check.
Uint8List fakePng(int width, int height) {
  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  return Uint8List.fromList([
    ...[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ...[0, 0, 0, 13],
    ...ascii.encode('IHDR'),
    ...ihdr.buffer.asUint8List(),
    ...[0, 0, 0, 0],
  ]);
}

/// Writes [bytes] to a temporary file deleted after the test and returns its path.
Future<String> tempFile(List<int> bytes, {String name = 'screen.png'}) async {
  final dir = await Directory.systemTemp.createTemp('a11y_file_');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file.path;
}

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
