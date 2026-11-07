import 'dart:io';

import 'package:args/command_runner.dart';

import 'cli_failure.dart';
import 'commands/check_command.dart';
import 'commands/native_command.dart';
import 'screenshotter.dart';

/// Parses the command line, runs a command and turns the outcome into an exit code.
class A11yCliRunner {
  A11yCliRunner({StringSink? out, StringSink? err, this.screenshotter}) : out = out ?? stdout, err = err ?? stderr;

  final StringSink out;
  final StringSink err;

  /// Makes the screenshotter for `check --html`; tests pass one with fake tools.
  final Screenshotter Function(String platform, String device)? screenshotter;

  /// 0 when the command ran, whatever it found; 1 on a usage, probe or connection failure.
  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>('a11y', 'Check what TalkBack and VoiceOver receive from a Flutter app.')
      ..addCommand(NativeCommand(out, err))
      ..addCommand(CheckCommand(out, err, screenshotter: screenshotter));
    if (args.isEmpty) {
      err.writeln(runner.usage);
      return 1;
    }
    try {
      return await runner.run(args) ?? 0;
    } on UsageException catch (e) {
      err
        ..writeln(e.message)
        ..writeln()
        ..writeln(e.usage);
      return 1;
    } on CliFailure catch (e) {
      err.writeln('a11y: ${e.message}');
      return 1;
    }
  }
}
