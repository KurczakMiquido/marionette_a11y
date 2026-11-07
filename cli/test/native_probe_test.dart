import 'dart:io';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  test('default probes dir is ../probes next to the cli package', () async {
    final dir = await NativeProbe.defaultProbesDir();

    expect(Directory(dir).resolveSymbolicLinksSync(), Directory('../probes').resolveSymbolicLinksSync());
    expect(File('$dir/android/run.sh').existsSync(), isTrue);
    expect(File('$dir/ios/run.sh').existsSync(), isTrue);
  });

  test('runs <probes>/<platform>/run.sh <device> <app> <out> and parses its output', () async {
    final probes = await fixtureProbes('native_ios', platform: 'ios');

    final tree = await NativeProbe(probesDir: probes.path, platform: 'ios', device: 'UDID-1', app: 'dev.app').run();

    expect(tree.platform, 'ios');
    expect(tree.nodes, hasLength((fixture('native_ios')['nodes'] as List).length));
    final args = recordedArgs(probes, platform: 'ios');
    expect(args.take(2), ['UDID-1', 'dev.app']);
    expect(args.last, endsWith('.json'));
    expect(File(args.last).existsSync(), isFalse, reason: 'the temporary output is removed');
  });

  test('a failing probe fails with its own reason', () async {
    final probes = await fakeProbes('echo "android probe: device emulator-9 is not connected" >&2; exit 1');

    expect(
      NativeProbe(probesDir: probes.path, platform: 'android', device: 'emulator-9', app: 'dev.app').run(),
      throwsA(
        isA<CliFailure>().having((e) => e.message, 'message', 'android probe: device emulator-9 is not connected'),
      ),
    );
  });

  test('a probe failing without a reason reports its exit code', () async {
    final probes = await fakeProbes('exit 3');

    expect(
      NativeProbe(probesDir: probes.path, platform: 'android', device: 'd', app: 'a').run(),
      throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('exited with code 3'))),
    );
  });

  test('a missing run.sh fails with its path', () async {
    final probes = await fakeProbes('true');

    expect(
      NativeProbe(probesDir: probes.path, platform: 'ios', device: 'd', app: 'a').run(),
      throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('${probes.path}/ios/run.sh'))),
    );
  });

  test('output that is not a11y-native/v1 fails', () async {
    final probes = await fakeProbes('echo \'{"schema": "a11y-native/v2"}\' > "\$3"');

    expect(
      NativeProbe(probesDir: probes.path, platform: 'android', device: 'd', app: 'a').run(),
      throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('a11y-native/v1'))),
    );
  });

  test('output that is not JSON fails', () async {
    final probes = await fakeProbes('echo nope > "\$3"');

    expect(
      NativeProbe(probesDir: probes.path, platform: 'android', device: 'd', app: 'a').run(),
      throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('not a valid'))),
    );
  });
}
