import 'dart:typed_data';

import '../cli_failure.dart';
import '../cross_check.dart';
import '../flutter_snapshot_client.dart';
import '../html_report.dart';
import '../screenshotter.dart';
import 'probe_command.dart';

/// `a11y check`: cross-checks the native tree against the Flutter semantics snapshot.
class CheckCommand extends ProbeCommand {
  CheckCommand(super.out, super.err, {Screenshotter Function(String platform, String device)? screenshotter})
    : _screenshotter = screenshotter ?? ((platform, device) => Screenshotter(platform: platform, device: device)) {
    argParser
      ..addOption('vm-service', mandatory: true, help: 'VM service URI of the running app (ws:// or http://).')
      ..addOption('locale', allowed: ['pl', 'en'], defaultsTo: 'pl', help: 'Language of the transcript.')
      ..addOption('html', help: 'Also write an HTML report with a screenshot of the screen to this file.');
  }

  final Screenshotter Function(String platform, String device) _screenshotter;

  @override
  String get name => 'check';

  @override
  String get description =>
      'Compare what TalkBack or VoiceOver receive with the Flutter semantics; write a11y-check/v1.';

  @override
  Future<int> execute() async {
    final htmlPath = argResults!.option('html');
    // Connect first so a wrong URI fails before the probe, which can take minutes on its first build.
    final client = await FlutterSnapshotClient.connect(argResults!.option('vm-service')!);
    try {
      // Before the probe, which can disturb the screen: on iOS XCUITest briefly brings its runner to the front.
      final screenshot = htmlPath == null ? null : await _screenshot();
      final native = await runProbe();
      final snapshot = await client.snapshot(locale: argResults!.option('locale')!);
      final report = CrossCheck.run(
        snapshot.nodes,
        native,
      ).withFlutter(flutterFindings: await client.audit(), transcript: snapshot.transcript);
      writeJson(report.toJson());
      // The check ran: print its result before the HTML, whose write can fail.
      out.write(report.summary());
      err.writeln('Wrote $outPath');
      if (htmlPath != null) {
        final misalignment = screenshot == null ? null : Screenshotter.misalignment(screenshot, native.screen);
        if (misalignment != null) err.writeln('a11y: $misalignment');
        final html = HtmlReport(
          report,
          device: argResults!.option('device')!,
          time: DateTime.now(),
          screenshot: screenshot,
          locale: argResults!.option('locale')!,
        ).render();
        writeText(htmlPath, html);
        err.writeln('Wrote $htmlPath');
      }
      return 0;
    } finally {
      await client.close();
    }
  }

  /// The screenshot, or null after telling why there is none; the report is written either way.
  Future<Uint8List?> _screenshot() async {
    try {
      return await _screenshotter(argResults!.option('platform')!, argResults!.option('device')!).capture();
    } on CliFailure catch (e) {
      err.writeln('a11y: no screenshot: ${e.message}');
      return null;
    }
  }
}
