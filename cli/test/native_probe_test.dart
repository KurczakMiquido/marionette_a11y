import 'dart:convert';
import 'dart:io';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

/// A probe that writes the [platform] fixture as read from [app] on [device].
Future<Directory> answeringProbes(String platform, {required String app, required String device}) async {
  final probes = await fakeProbes('cp "\$(dirname "\$0")/tree.json" "\$3"', platform: platform);
  final json = fixture('native_$platform')
    ..['app'] = app
    ..['device'] = device;
  File('${probes.path}/$platform/tree.json').writeAsStringSync(jsonEncode(json));
  return probes;
}

void main() {
  test('default probes dir is ../probes next to the cli package', () async {
    final dir = await NativeProbe.defaultProbesDir();

    expect(Directory(dir).resolveSymbolicLinksSync(), Directory('../probes').resolveSymbolicLinksSync());
    expect(File('$dir/android/run.sh').existsSync(), isTrue);
    expect(File('$dir/ios/run.sh').existsSync(), isTrue);
  });

  test('runs <probes>/<platform>/run.sh <device> <app> <out> and parses its output', () async {
    final probes = await answeringProbes('ios', app: 'dev.app', device: 'UDID-1');

    final tree = await NativeProbe(probesDir: probes.path, platform: 'ios', device: 'UDID-1', app: 'dev.app').run();

    expect(tree.platform, 'ios');
    expect(tree.nodes, hasLength((fixture('native_ios')['nodes'] as List).length));
    final args = recordedArgs(probes, platform: 'ios');
    expect(args.take(2), ['UDID-1', 'dev.app']);
    expect(args.last, endsWith('.json'));
    expect(File(args.last).existsSync(), isFalse, reason: 'the temporary output is removed');
  });

  group('the tree must come from the requested app and device', () {
    Future<NativeTree> run(String platform, {required String answeredApp, required String answeredDevice}) async {
      final probes = await answeringProbes(platform, app: answeredApp, device: answeredDevice);
      return NativeProbe(probesDir: probes.path, platform: platform, device: 'Device-1', app: 'dev.app').run();
    }

    test('another app fails', () {
      expect(
        run('android', answeredApp: 'dev.other', answeredDevice: 'Device-1'),
        throwsA(
          isA<CliFailure>().having(
            (e) => e.message,
            'message',
            'android probe read app "dev.other" instead of "dev.app"',
          ),
        ),
      );
    });

    test('another device fails', () {
      expect(
        run('ios', answeredApp: 'dev.app', answeredDevice: 'Device-2'),
        throwsA(
          isA<CliFailure>().having(
            (e) => e.message,
            'message',
            'ios probe read device "Device-2" instead of "Device-1"',
          ),
        ),
      );
    });

    test('iOS compares UDIDs case-insensitively', () async {
      expect((await run('ios', answeredApp: 'dev.app', answeredDevice: 'DEVICE-1')).device, 'DEVICE-1');
    });

    test('Android compares serials exactly', () {
      expect(run('android', answeredApp: 'dev.app', answeredDevice: 'DEVICE-1'), throwsA(isA<CliFailure>()));
    });

    test('an empty device passes, as the probe could not tell', () async {
      expect((await run('ios', answeredApp: 'dev.app', answeredDevice: '')).device, isEmpty);
    });
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
