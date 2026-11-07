import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'cli_failure.dart';
import 'models/native_tree.dart';

/// Runs `<probesDir>/<platform>/run.sh <device> <app> <out.json>` and reads its `a11y-native/v1` output.
class NativeProbe {
  const NativeProbe({required this.probesDir, required this.platform, required this.device, required this.app});

  final String probesDir;
  final String platform;
  final String device;
  final String app;

  /// `../probes` relative to the `a11y_cli` package root.
  static Future<String> defaultProbesDir() async {
    final library = await Isolate.resolvePackageUri(Uri.parse('package:a11y_cli/a11y_cli.dart'));
    if (library == null) throw const CliFailure('cannot locate the a11y_cli package; pass --probes-dir');
    return library.resolve('../../probes').toFilePath();
  }

  String get script => '$probesDir/$platform/run.sh';

  Future<NativeTree> run() async {
    if (!File(script).existsSync()) throw CliFailure('probe script not found: $script');
    final tmp = await Directory.systemTemp.createTemp('a11y_native_');
    try {
      final out = '${tmp.path}/native.json';
      final ProcessResult result;
      try {
        result = await Process.run(script, [device, app, out]);
      } on ProcessException catch (e) {
        throw CliFailure('cannot run $script: ${e.message}');
      }
      if (result.exitCode != 0) {
        final reason = (result.stderr as String).trim();
        throw CliFailure(reason.isNotEmpty ? reason : '$platform probe exited with code ${result.exitCode}');
      }
      try {
        return NativeTree.fromJson(jsonDecode(await File(out).readAsString()) as Map<String, dynamic>);
      } on Object catch (e) {
        // The models cast fields with `as`, so a malformed document surfaces as a TypeError too.
        if (e is! FormatException && e is! TypeError && e is! FileSystemException) rethrow;
        throw CliFailure('$platform probe output is not a valid ${NativeTree.schema} document: $e');
      }
    } finally {
      await tmp.delete(recursive: true);
    }
  }
}
