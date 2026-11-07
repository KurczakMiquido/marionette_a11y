import 'dart:io';

void main(List<String> args) {
  stderr.writeln('''
Usage:
  a11y native --platform android|ios --device <id> --app <appId> --out native.json
  a11y check  --platform android|ios --device <id> --app <appId> --vm-service <ws uri> --out check.json''');
  exit(1);
}
