import 'dart:convert';
import 'dart:io';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

const androidApp = 'dev.poc.marionette_a11y_example';

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

  Future<int> run(List<String> args, {String adb = 'adb'}) => A11yCliRunner(
    out: out,
    err: err,
    screenshotter: (platform, device) => Screenshotter(platform: platform, device: device, adb: adb),
  ).run(args);

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
        ...['--platform', 'android', '--device', 'emulator-5580', '--app', androidApp],
        ...['--out', outFile, '--probes-dir', probes.path],
      ]);

      expect(code, 0, reason: err.toString());
      expect(jsonDecode(File(outFile).readAsStringSync()), fixture('native_android'));
      expect(recordedArgs(probes).take(2), ['emulator-5580', androidApp]);
      expect(out.toString(), contains('8 nodes and 3 issues'));
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
        ...['--platform', 'android', '--device', 'emulator-5580', '--app', androidApp, '--out', outFile],
        ...['--vm-service', await startFakeApp(), '--probes-dir', probes.path],
      ]);

      expect(code, 0, reason: err.toString());
      final report = jsonDecode(File(outFile).readAsStringSync()) as Map<String, dynamic>;
      expect(report['schema'], 'a11y-check/v1');
      expect(report['native'], fixture('native_android'));
      expect(report['flutter'], {
        'nodes': fixture('flutter_snapshot')['nodes'],
        'transcript': fixture('flutter_snapshot')['transcript'],
      });
      expect(report['matches'], hasLength(5));
      final sources = [for (final f in report['findings'] as List) (f as Map)['source']];
      expect(sources.take(9), everyElement('flutter'));
      expect(sources.skip(9), isNot(contains('flutter')));
      expect(sources.skip(9).first, 'crosscheck');
      expect(sources.last, 'atf');
      expect(
        out.toString(),
        startsWith('error: 7, warning: 7, info: 0\n[warning] missing-role — "Umów wizytę" reacts to taps'),
      );
      expect(out.toString(), contains('[error] not-exposed — Flutter node 42 "Lipidogram"'));
      expect(out.toString().trim().split('\n'), hasLength(15));
    });

    test('--locale reaches the snapshot call; the default is pl', () async {
      final probes = await fixtureProbes('native_android');
      Future<List<dynamic>> transcript(List<String> extra) async {
        final outFile = '${tmp.path}/check${extra.length}.json';
        final code = await run([
          'check',
          ...['--platform', 'android', '--device', 'emulator-5580', '--app', androidApp, '--out', outFile],
          ...['--vm-service', await startFakeApp(), '--probes-dir', probes.path, ...extra],
        ]);
        expect(code, 0, reason: err.toString());
        final report = jsonDecode(File(outFile).readAsStringSync()) as Map<String, dynamic>;
        return (report['flutter'] as Map)['transcript'] as List;
      }

      expect(await transcript([]), fixture('flutter_snapshot')['transcript']);
      expect(await transcript(['--locale', 'en']), everyElement(endsWith(' [en]')));
    });

    test('an unknown --locale exits 1', () async {
      final code = await run([
        'check',
        ...['--platform', 'android', '--device', 'd', '--app', 'a', '--out', 'x.json'],
        ...['--vm-service', 'ws://127.0.0.1:9/x/ws', '--locale', 'de'],
      ]);

      expect(code, 1);
      expect(err.toString(), contains('"de" is not an allowed value'));
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

  group('check --html', () {
    late Directory probes;
    late String jsonFile;
    late String htmlFile;

    setUp(() async {
      probes = await fixtureProbes('native_android');
      jsonFile = '${tmp.path}/check.json';
      htmlFile = '${tmp.path}/check.html';
    });

    Future<int> check(String adb, {bool html = true, String? vmService}) async => run([
      'check',
      ...['--platform', 'android', '--device', 'emulator-5580', '--app', androidApp, '--out', jsonFile],
      ...['--vm-service', vmService ?? await startFakeApp(), '--probes-dir', probes.path],
      if (html) ...['--html', htmlFile],
    ], adb: adb);

    test('writes the JSON and an HTML report with the screenshot, and exits 0', () async {
      final png = fakePng(1080, 2400);
      final adb = await fakeTool('adb', 'cat "${await tempFile(png)}"');

      expect(await check(adb), 0, reason: err.toString());

      expect(toolArgs(adb), ['-s', 'emulator-5580', 'exec-out', 'screencap', '-p']);
      expect(File(jsonFile).existsSync(), isTrue);
      final html = File(htmlFile).readAsStringSync();
      expect(html, contains('data:image/png;base64,${base64Encode(png)}'));
      expect(html, contains('id="g1"'));
      expect(html, contains('<h3>Whole screen</h3>'), reason: 'the fixture audit has a screen-level finding');
      expect(err.toString(), isNot(contains('a11y:')));
      expect(err.toString(), contains('Wrote $htmlFile'));
      expect(out.toString(), startsWith('error: 7, warning: 7, info: 0\n'));
    });

    test('a failed screenshot is reported and the report is written without one', () async {
      final adb = await fakeTool('adb', 'echo "adb: device \'emulator-5580\' not found" >&2; exit 1');

      expect(await check(adb), 0, reason: err.toString());

      expect(err.toString(), contains("a11y: no screenshot: adb: device 'emulator-5580' not found\n"));
      final html = File(htmlFile).readAsStringSync();
      expect(html, isNot(contains('<img')));
      expect(html, contains('aspect-ratio:411.4 / 914.3'));
      expect(File(jsonFile).existsSync(), isTrue);
    });

    test('warns when the screenshot does not cover the screen at its scale', () async {
      final adb = await fakeTool('adb', 'cat "${await tempFile(fakePng(540, 1200))}"');

      expect(await check(adb), 0, reason: err.toString());

      expect(
        err.toString(),
        contains(
          'a11y: screenshot is 540x1200 px but the screen is 411.4x914.3 pt at scale 2.625; boxes may not align\n',
        ),
      );
      expect(File(htmlFile).readAsStringSync(), contains('data:image/png;base64,'));
    });

    test('the screenshot is taken after connecting and before the probe runs', () async {
      final log = '${tmp.path}/order.log';
      probes = await fakeProbes('echo probe >> "$log"; cp "${fixturePath('native_android')}" "\$3"');
      final adb = await fakeTool('adb', 'echo screenshot >> "$log"; cat "${await tempFile(fakePng(1080, 2400))}"');

      expect(await check(adb), 0, reason: err.toString());
      expect(File(log).readAsLinesSync(), ['screenshot', 'probe']);
    });

    test('an unreachable VM service fails before the screenshot', () async {
      final adb = await fakeTool('adb', 'true');

      expect(await check(adb, vmService: 'ws://127.0.0.1:9/nothing/ws'), 1);
      expect(toolArgs(adb), isNull);
      expect(File(htmlFile).existsSync(), isFalse);
    });

    test('an unwritable --html path still prints the summary, then exits 1', () async {
      final adb = await fakeTool('adb', 'cat "${await tempFile(fakePng(1080, 2400))}"');
      htmlFile = '${tmp.path}/missing/check.html';

      expect(await check(adb), 1);

      expect(out.toString(), startsWith('error: 7, warning: 7, info: 0\n'));
      expect(err.toString(), contains('cannot write $htmlFile'));
    });

    test('without --html no screenshot is taken', () async {
      final adb = await fakeTool('adb', 'true');

      expect(await check(adb, html: false), 0, reason: err.toString());
      expect(toolArgs(adb), isNull);
      expect(File(htmlFile).existsSync(), isFalse);
    });
  });
}
