/// A failure the CLI reports as one line and exit code 1: a probe, the VM service or a file could not do its part.
class CliFailure implements Exception {
  const CliFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
