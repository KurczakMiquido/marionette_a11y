import 'dart:convert';
import 'dart:io';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late Directory tmp;

  setUp(() async {
    out = StringBuffer();
    err = StringBuffer();
    tmp = await Directory.systemTemp.createTemp('a11y_cli_');
    addTearDown(() => tmp.delete(recursive: true));
  });

  Future<int> run(List<String> args) => A11yCliRunner(out: out, err: err).run(args);

  group('usage', () {
    test('no command exits 1 with usage', () async {
      expect(await run([]), 1);
      expect(err.toString(), contains('Usage: a11y <command>'));
    });

    test('an unknown platform exits 1', () async {
      final code = await run(['native', '--platform', 'web', '--device', 'd', '--app', 'a', '--out', 'x.json']);

      expect(code, 1);
      expect(err.toString(), contains('"web" is not an allowed value'));
    });

    test('a missing mandatory option exits 1', () async {
      expect(await run(['native', '--platform', 'android', '--device', 'd', '--app', 'a']), 1);
      expect(err.toString(), contains('Option out is mandatory'));
    });

    test('check needs --vm-service', () async {
      expect(await run(['check', '--platform', 'ios', '--device', 'd', '--app', 'a', '--out', 'x.json']), 1);
      expect(err.toString(), contains('Option vm-service is mandatory'));
    });

    test('positional arguments exit 1', () async {
      final code = await run(['native', '--platform', 'ios', '--device', 'd', '--app', 'a', '--out', 'x', 'extra']);

      expect(code, 1);
      expect(err.toString(), contains('does not take any arguments'));
    });
  });

  group('native', () {
    test('writes the probe output to --out and exits 0', () async {
      final probes = await fixtureProbes('native_android');
      final outFile = '${tmp.path}/native.json';

      final code = await run([
        'native',
        ...['--platform', 'android', '--device', 'emulator-5580', '--app', 'dev.app'],
        ...['--out', outFile, '--probes-dir', probes.path],
      ]);

      expect(code, 0, reason: err.toString());
      expect(jsonDecode(File(outFile).readAsStringSync()), fixture('native_android'));
      expect(recordedArgs(probes).take(2), ['emulator-5580', 'dev.app']);
      expect(out.toString(), contains('5 nodes and 1 issue'));
    });

    test('a probe failure exits 1 with its reason and writes nothing', () async {
      final probes = await fakeProbes('echo "android probe: device d is not connected" >&2; exit 1');
      final outFile = '${tmp.path}/native.json';

      final code = await run([
        'native',
        ...['--platform', 'android', '--device', 'd', '--app', 'a', '--out', outFile, '--probes-dir', probes.path],
      ]);

      expect(code, 1);
      expect(err.toString(), contains('android probe: device d is not connected'));
      expect(File(outFile).existsSync(), isFalse);
    });
  });

  group('check', () {
    test('writes a11y-check/v1, prints the summary and exits 0', () async {
      final probes = await fixtureProbes('native_android');
      final outFile = '${tmp.path}/check.json';

      final code = await run([
        'check',
        ...['--platform', 'android', '--device', 'emulator-5580', '--app', 'dev.app', '--out', outFile],
        ...['--vm-service', await startFakeApp(), '--probes-dir', probes.path],
      ]);

      expect(code, 0, reason: err.toString());
      final report = jsonDecode(File(outFile).readAsStringSync()) as Map<String, dynamic>;
      expect(report['schema'], 'a11y-check/v1');
      expect(report['native'], fixture('native_android'));
      expect(report['flutter'], {'nodes': fixture('flutter_snapshot')['nodes']});
      expect(report['matches'], hasLength(3));
      expect(out.toString(), startsWith('error: 3, warning: 0, info: 0\n[error] not-exposed — Flutter node 5 "Menu"'));
      expect(out.toString().trim().split('\n'), hasLength(4));
    });

    test('an unreachable VM service exits 1 before running the probe', () async {
      final probes = await fixtureProbes('native_android');

      final code = await run([
        'check',
        ...['--platform', 'android', '--device', 'd', '--app', 'a', '--out', '${tmp.path}/check.json'],
        ...['--vm-service', 'ws://127.0.0.1:9/nothing/ws', '--probes-dir', probes.path],
      ]);

      expect(code, 1);
      expect(err.toString(), contains('VM service'));
      expect(File('${probes.path}/android/args.txt').existsSync(), isFalse);
    });
  });
}
