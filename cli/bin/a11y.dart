import 'dart:io';

import 'package:a11y_cli/a11y_cli.dart';

Future<void> main(List<String> args) async {
  final code = await A11yCliRunner().run(args);
  await Future.wait([stdout.flush(), stderr.flush()]);
  exit(code);
}
