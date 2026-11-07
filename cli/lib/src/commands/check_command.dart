import '../cross_check.dart';
import '../flutter_snapshot_client.dart';
import 'probe_command.dart';

/// `a11y check`: cross-checks the native tree against the Flutter semantics snapshot.
class CheckCommand extends ProbeCommand {
  CheckCommand(super.out, super.err) {
    argParser.addOption('vm-service', mandatory: true, help: 'VM service URI of the running app (ws:// or http://).');
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Compare what TalkBack or VoiceOver receive with the Flutter semantics; write a11y-check/v1.';

  @override
  Future<int> execute() async {
    // Connect first so a wrong URI fails before the probe, which can take minutes on its first build.
    final client = await FlutterSnapshotClient.connect(argResults!.option('vm-service')!);
    try {
      final native = await runProbe();
      final report = CrossCheck.run(await client.snapshot(), native);
      writeJson(report.toJson());
      out.write(report.summary());
      err.writeln('Wrote $outPath');
      return 0;
    } finally {
      await client.close();
    }
  }
}
