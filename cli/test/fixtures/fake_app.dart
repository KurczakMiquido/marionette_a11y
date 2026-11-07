// A stand-in for a running Flutter app: serves the snapshot and audit fixtures as `ext.flutter.a11y.snapshot` and
// `ext.flutter.a11y.audit` over its own VM service and prints the service's WebSocket URI.
// Flags: `--no-extension` leaves both out, `--hang-audit` never answers the audit call. The transcript lines carry
// a ` [en]` suffix when the snapshot was asked for locale `en`, so tests can see the locale arrive.
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

Future<void> main(List<String> args) async {
  final snapshot = jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final audit = File(args[1]).readAsStringSync();
  if (!args.contains('--no-extension')) {
    registerExtension('ext.flutter.a11y.snapshot', (method, params) async {
      if (params['includeRects'] != 'true') {
        return ServiceExtensionResponse.error(ServiceExtensionResponse.invalidParams, 'includeRects must be true');
      }
      final suffix = params['locale'] == 'en' ? ' [en]' : '';
      return ServiceExtensionResponse.result(
        jsonEncode({
          ...snapshot,
          'transcript': [for (final line in snapshot['transcript'] as List) '$line$suffix'],
        }),
      );
    });
    registerExtension('ext.flutter.a11y.audit', (method, params) async {
      if (args.contains('--hang-audit')) await Completer<void>().future;
      return ServiceExtensionResponse.result(audit);
    });
  }
  final info = await Service.controlWebServer(enable: true, silenceOutput: true);
  stdout.writeln(info.serverWebSocketUri);
  // Stay alive until the test closes stdin.
  await stdin.drain<void>();
}
