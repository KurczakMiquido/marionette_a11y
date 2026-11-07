import 'dart:io';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

const _androidScreen = NativeScreen(width: 411.4, height: 914.3, scale: 2.625);

Matcher _failsWith(Object message) => throwsA(isA<CliFailure>().having((e) => e.message, 'message', message));

void main() {
  group('capture', () {
    test('Android reads the PNG from adb exec-out screencap -p', () async {
      final png = fakePng(1080, 2400);
      final adb = await fakeTool('adb', 'cat "${await tempFile(png)}"');

      final shot = await Screenshotter(platform: 'android', device: 'emulator-5580', adb: adb).capture();

      expect(shot, png);
      expect(toolArgs(adb), ['-s', 'emulator-5580', 'exec-out', 'screencap', '-p']);
    });

    test('iOS reads the PNG simctl io screenshot wrote, then removes it', () async {
      final png = fakePng(1206, 2622);
      final xcrun = await fakeTool('xcrun', 'cp "${await tempFile(png)}" "\${@: -1}"');

      final shot = await Screenshotter(platform: 'ios', device: 'UDID-1', xcrun: xcrun).capture();

      expect(shot, png);
      final args = toolArgs(xcrun)!;
      expect(args.take(5), ['simctl', 'io', 'UDID-1', 'screenshot', '--type=png']);
      expect(args, hasLength(6));
      expect(args.last, endsWith('.png'));
      expect(File(args.last).existsSync(), isFalse, reason: 'the temporary file is removed');
    });

    test('a failing tool fails with its stderr on one line', () async {
      final xcrun = await fakeTool(
        'xcrun',
        'printf "An error was encountered (code=405):\\nUnable to lookup\\n" >&2; exit 1',
      );

      expect(
        Screenshotter(platform: 'ios', device: 'UDID-1', xcrun: xcrun).capture(),
        _failsWith('An error was encountered (code=405): Unable to lookup'),
      );
    });

    test('a failing tool without stderr reports its exit code', () async {
      final adb = await fakeTool('adb', 'exit 3');

      expect(
        Screenshotter(platform: 'android', device: 'd', adb: adb).capture(),
        _failsWith('$adb exited with code 3'),
      );
    });

    test('output that is not a PNG fails', () async {
      final adb = await fakeTool('adb', 'echo "screencap: no display"');

      expect(
        Screenshotter(platform: 'android', device: 'd', adb: adb).capture(),
        _failsWith('$adb did not return a PNG'),
      );
    });

    test('a file that cannot be read fails with a reason, not a crash', () async {
      final xcrun = await fakeTool(
        'xcrun',
        'cp "${await tempFile(fakePng(1206, 2622))}" "\${@: -1}"; chmod 000 "\${@: -1}"',
      );

      expect(
        Screenshotter(platform: 'ios', device: 'UDID-1', xcrun: xcrun).capture(),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', startsWith('cannot read the screenshot: '))),
      );
    });

    test('a tool that cannot run fails with its path', () {
      expect(
        const Screenshotter(platform: 'android', device: 'd', adb: '/nonexistent/adb').capture(),
        _failsWith(startsWith('cannot run /nonexistent/adb: ')),
      );
    });
  });

  group('pngSize', () {
    test('reads width and height from the IHDR chunk', () {
      expect(Screenshotter.pngSize(fakePng(1080, 2400)), (width: 1080, height: 2400));
      expect(Screenshotter.pngSize(fakePng(70000, 3)), (width: 70000, height: 3));
    });

    test('bytes that are not a PNG throw', () {
      expect(() => Screenshotter.pngSize([1, 2, 3]), throwsFormatException);
      expect(() => Screenshotter.pngSize(List.filled(24, 0)), throwsFormatException);
    });
  });

  group('misalignment', () {
    test('null when the PNG width over the scale is within 2% of the screen width', () {
      expect(Screenshotter.misalignment(fakePng(1080, 2400), _androidScreen), isNull);
      // 1100 / 2.625 = 419.0 pt, 1.9% wider.
      expect(Screenshotter.misalignment(fakePng(1100, 2400), _androidScreen), isNull);
    });

    test('a warning when it is more than 2% off', () {
      // 1110 / 2.625 = 422.9 pt, 2.8% wider.
      expect(
        Screenshotter.misalignment(fakePng(1110, 2400), _androidScreen),
        'screenshot is 1110x2400 px but the screen is 411.4x914.3 pt at scale 2.625; boxes may not align',
      );
      expect(
        Screenshotter.misalignment(fakePng(402, 874), const NativeScreen(width: 402, height: 874, scale: 3)),
        'screenshot is 402x874 px but the screen is 402x874 pt at scale 3; boxes may not align',
      );
    });
  });
}
