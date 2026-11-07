import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'cli_failure.dart';
import 'models/flutter_node.dart';

/// Reads the Flutter semantics snapshot from a running app over its VM service.
class FlutterSnapshotClient {
  FlutterSnapshotClient._(this._service, this._isolateId);

  static const extension = 'ext.flutter.a11y.snapshot';
  static const _connectTimeout = Duration(seconds: 10);

  final VmService _service;
  final String _isolateId;

  /// Accepts the `ws://…/ws` URI, or the `http://…/` one Flutter apps log at start-up.
  static Uri webSocketUri(String uri) {
    final parsed = Uri.tryParse(uri);
    switch (parsed?.scheme) {
      case 'ws' || 'wss':
        return parsed!;
      case 'http' || 'https':
        final segments = [...parsed!.pathSegments.where((s) => s.isNotEmpty), 'ws'];
        return parsed.replace(scheme: parsed.scheme == 'https' ? 'wss' : 'ws', pathSegments: segments);
      default:
        throw CliFailure('--vm-service must be a ws:// or http:// URI, got "$uri"');
    }
  }

  /// Connects and finds the isolate that registered [extension].
  static Future<FlutterSnapshotClient> connect(String uri) async {
    final wsUri = webSocketUri(uri);
    final VmService service;
    try {
      service = await vmServiceConnectUri(wsUri.toString()).timeout(_connectTimeout);
    } on Exception catch (e) {
      throw CliFailure('cannot connect to the VM service at $wsUri: $e');
    }
    String? isolateId;
    try {
      for (final ref in (await service.getVM()).isolates ?? <IsolateRef>[]) {
        try {
          if ((await service.getIsolate(ref.id!)).extensionRPCs?.contains(extension) ?? false) {
            isolateId = ref.id;
            break;
          }
        } on SentinelException {
          // The isolate exited while we looked; the others may still expose the extension.
        }
      }
    } on RPCError catch (e) {
      throw CliFailure('VM service at $wsUri failed: ${e.message}');
    } finally {
      if (isolateId == null) await service.dispose();
    }
    if (isolateId == null) {
      throw CliFailure('no isolate at $wsUri exposes $extension; does the app call registerA11yExtensions()?');
    }
    return FlutterSnapshotClient._(service, isolateId);
  }

  Future<List<FlutterNode>> snapshot() async {
    final Response response;
    try {
      response = await _service.callServiceExtension(extension, isolateId: _isolateId, args: {'includeRects': 'true'});
    } on RPCError catch (e) {
      throw CliFailure('$extension failed: ${e.details ?? e.message}');
    } on SentinelException {
      throw const CliFailure('the app isolate exited before the snapshot was taken');
    }
    try {
      return [for (final n in response.json!['nodes'] as List) FlutterNode.fromJson(n as Map<String, dynamic>)];
    } on Object catch (e) {
      if (e is! FormatException && e is! TypeError) rethrow;
      throw CliFailure('$extension returned an unexpected snapshot: $e');
    }
  }

  Future<void> close() => _service.dispose();
}
