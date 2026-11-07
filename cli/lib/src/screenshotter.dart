import 'dart:io';
import 'dart:typed_data';

import 'cli_failure.dart';
import 'models/native_screen.dart';

/// Takes a PNG of the device screen: `adb exec-out screencap -p` on Android, `xcrun simctl io screenshot` on iOS.
class Screenshotter {
  const Screenshotter({required this.platform, required this.device, this.adb = 'adb', this.xcrun = 'xcrun'});

  static const _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const _maxOffset = 0.02;

  final String platform;
  final String device;

  /// Executables to run; tests put fakes here.
  final String adb;
  final String xcrun;

  /// The PNG bytes. Throws a [CliFailure] with a one-line reason when no PNG came back.
  Future<Uint8List> capture() async {
    if (platform == 'android') {
      final result = await _run(adb, ['-s', device, 'exec-out', 'screencap', '-p']);
      return _checked(adb, Uint8List.fromList(result.stdout as List<int>));
    }
    final Directory tmp;
    try {
      tmp = await Directory.systemTemp.createTemp('a11y_screenshot_');
    } on FileSystemException catch (e) {
      throw CliFailure('cannot create a temporary directory: ${e.osError?.message ?? e.message}');
    }
    try {
      final file = File('${tmp.path}/screen.png');
      await _run(xcrun, ['simctl', 'io', device, 'screenshot', '--type=png', file.path]);
      return _checked(xcrun, file.existsSync() ? await file.readAsBytes() : Uint8List(0));
    } on FileSystemException catch (e) {
      throw CliFailure('cannot read the screenshot: ${e.osError?.message ?? e.message}');
    } finally {
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // A leftover temp dir is not worth failing the report.
      }
    }
  }

  static Future<ProcessResult> _run(String executable, List<String> args) async {
    final ProcessResult result;
    try {
      result = await Process.run(executable, args, stdoutEncoding: null);
    } on ProcessException catch (e) {
      throw CliFailure('cannot run $executable: ${e.message}');
    }
    if (result.exitCode != 0) {
      // simctl explains itself over several lines; the CLI reports one.
      final reason = (result.stderr as String).replaceAll(RegExp(r'\s+'), ' ').trim();
      throw CliFailure(reason.isNotEmpty ? reason : '$executable exited with code ${result.exitCode}');
    }
    return result;
  }

  static Uint8List _checked(String executable, Uint8List png) {
    try {
      pngSize(png);
    } on FormatException {
      throw CliFailure('$executable did not return a PNG');
    }
    return png;
  }

  /// Width and height in pixels from the IHDR chunk (bytes 16–23, big-endian). Throws a [FormatException] when [png]
  /// does not start like a PNG.
  static ({int width, int height}) pngSize(List<int> png) {
    final header = Uint8List.fromList(png.take(24).toList());
    final isPng =
        header.length == 24 &&
        Iterable<int>.generate(_signature.length).every((i) => header[i] == _signature[i]) &&
        String.fromCharCodes(header, 12, 16) == 'IHDR';
    if (!isPng) throw const FormatException('not a PNG');
    final data = ByteData.sublistView(header);
    return (width: data.getUint32(16), height: data.getUint32(20));
  }

  /// The warning when [png] is more than 2% wider or narrower than [screen] at its scale, else null.
  static String? misalignment(List<int> png, NativeScreen screen) {
    final (:width, :height) = pngSize(png);
    if ((width / screen.scale - screen.width).abs() <= _maxOffset * screen.width) return null;
    return 'screenshot is ${width}x$height px but the screen is ${_number(screen.width)}x${_number(screen.height)} pt '
        'at scale ${_number(screen.scale)}; boxes may not align';
  }

  static String _number(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
