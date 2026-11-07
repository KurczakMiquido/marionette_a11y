import 'probe_command.dart';

/// `a11y native`: dumps the native accessibility tree and the platform's own issues.
class NativeCommand extends ProbeCommand {
  NativeCommand(super.out, super.err);

  @override
  String get name => 'native';

  @override
  String get description => 'Read the native accessibility tree of the app on screen and write a11y-native/v1.';

  @override
  Future<int> execute() async {
    final tree = await runProbe();
    writeJson(tree.toJson());
    final issues = tree.issues.length;
    out.writeln('Wrote ${tree.nodes.length} nodes and $issues ${issues == 1 ? 'issue' : 'issues'} to $outPath');
    return 0;
  }
}
