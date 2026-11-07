import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_failure.dart';
import '../native_probe.dart';
import '../models/native_tree.dart';

/// Options and steps shared by the commands that run a native probe.
abstract class ProbeCommand extends Command<int> {
  ProbeCommand(this.out, this.err) {
    argParser
      ..addOption('platform', allowed: ['android', 'ios'], mandatory: true, help: 'Platform of the device.')
      ..addOption('device', mandatory: true, help: 'adb serial (Android) or simulator UDID (iOS).')
      ..addOption('app', mandatory: true, help: 'Package name (Android) or bundle identifier (iOS).')
      ..addOption('out', mandatory: true, help: 'Where to write the JSON result.')
      ..addOption('probes-dir', help: 'Directory with <platform>/run.sh. Default: ../probes next to the cli package.');
  }

  final StringSink out;
  final StringSink err;

  @override
  bool get takesArguments => false;

  /// The command itself, run once the options are complete.
  Future<int> execute();

  @override
  Future<int> run() {
    // args checks mandatory options only when they are read, and then throws an ArgumentError.
    for (final option in argParser.options.values) {
      if (option.mandatory && !argResults!.wasParsed(option.name)) {
        usageException('Option ${option.name} is mandatory.');
      }
    }
    return execute();
  }

  String get outPath => argResults!.option('out')!;

  Future<NativeTree> runProbe() async {
    final args = argResults!;
    final platform = args.option('platform')!;
    final device = args.option('device')!;
    final probe = NativeProbe(
      probesDir: args.option('probes-dir') ?? await NativeProbe.defaultProbesDir(),
      platform: platform,
      device: device,
      app: args.option('app')!,
    );
    err.writeln('Running the $platform probe on $device (it builds itself first when needed)...');
    return probe.run();
  }

  void writeJson(Map<String, dynamic> json) {
    try {
      File(outPath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
    } on FileSystemException catch (e) {
      throw CliFailure('cannot write $outPath: ${e.osError?.message ?? e.message}');
    }
  }
}
