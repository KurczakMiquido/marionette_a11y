// A stand-in for a running Flutter app: serves the snapshot fixture as `ext.flutter.a11y.snapshot` over its own
// VM service and prints the service's WebSocket URI. Pass `--no-extension` to leave the extension out.
import 'dart:developer';
import 'dart:io';

Future<void> main(List<String> args) async {
  final snapshot = File(args.first).readAsStringSync();
  if (!args.contains('--no-extension')) {
    registerExtension('ext.flutter.a11y.snapshot', (method, params) async {
      if (params['includeRects'] != 'true') {
        return ServiceExtensionResponse.error(ServiceExtensionResponse.invalidParams, 'includeRects must be true');
      }
      return ServiceExtensionResponse.result(snapshot);
    });
  }
  final info = await Service.controlWebServer(enable: true, silenceOutput: true);
  stdout.writeln(info.serverWebSocketUri);
  // Stay alive until the test closes stdin.
  await stdin.drain<void>();
}
