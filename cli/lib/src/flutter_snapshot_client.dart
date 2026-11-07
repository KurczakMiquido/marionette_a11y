import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'cli_failure.dart';
import 'models/a11y_rect.dart';
import 'models/finding.dart';
import 'models/flutter_node.dart';

/// Reads the Flutter semantics snapshot and the in-app audit from a running app over its VM service.
class FlutterSnapshotClient {
  FlutterSnapshotClient._(this._service, this._isolateId, this._callTimeout);

  static const extension = 'ext.flutter.a11y.snapshot';
  static const auditExtension = 'ext.flutter.a11y.audit';
  static const _connectTimeout = Duration(seconds: 10);

  /// An app paused in a debugger never answers; without a limit the CLI would wait forever.
  static const defaultCallTimeout = Duration(seconds: 30);

  final VmService _service;
  final String _isolateId;
  final Duration _callTimeout;

  /// Accepts the `ws://…/ws` URI, or the `http://…/` one Flutter apps log at start-up.
  static Uri webSocketUri(String uri) {
    final parsed = Uri.tryParse(uri);
    switch (parsed?.scheme) {
      case 'ws' || 'wss':
        return parsed!;
      case 'http' || 'https':
        final segments = [...parsed!.pathSegments.where((s) => s.isNotEmpty)];
        if (segments.lastOrNull != 'ws') segments.add('ws');
        return parsed.replace(scheme: parsed.scheme == 'https' ? 'wss' : 'ws', pathSegments: segments);
      default:
        throw CliFailure('--vm-service must be a ws:// or http:// URI, got "$uri"');
    }
  }

  /// Connects and finds the isolate that registered [extension].
  static Future<FlutterSnapshotClient> connect(String uri, {Duration callTimeout = defaultCallTimeout}) async {
    final wsUri = webSocketUri(uri);
    final VmService service;
    try {
      service = await vmServiceConnectUri(wsUri.toString()).timeout(_connectTimeout);
    } on Exception catch (e) {
      throw CliFailure('cannot connect to the VM service at $wsUri: $e');
    }
    String? isolateId;
    try {
      for (final ref in (await _within(callTimeout, 'getVM', service.getVM())).isolates ?? <IsolateRef>[]) {
        try {
          final isolate = await _within(callTimeout, 'getIsolate', service.getIsolate(ref.id!));
          if (isolate.extensionRPCs?.contains(extension) ?? false) {
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
    return FlutterSnapshotClient._(service, isolateId, callTimeout);
  }

  /// Fails with a [CliFailure] naming [call] when [future] has not completed within [timeout].
  static Future<T> _within<T>(Duration timeout, String call, Future<T> future) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      final seconds = timeout.inMilliseconds / 1000;
      final shown = seconds == seconds.roundToDouble() ? seconds.round() : seconds;
      throw CliFailure('VM service did not answer $call within $shown s; is the app paused in a debugger?');
    }
  }

  Future<Map<String, dynamic>> _call(String method, Map<String, String> args, String what) async {
    final Response response;
    try {
      response = await _within(
        _callTimeout,
        method,
        _service.callServiceExtension(method, isolateId: _isolateId, args: args),
      );
    } on RPCError catch (e) {
      throw CliFailure('$method failed: ${e.details ?? e.message}');
    } on SentinelException {
      throw CliFailure('the app isolate exited before the $what was taken');
    }
    return response.json!;
  }

  /// The swipe-order transcript in [locale] and the semantics nodes with their rects.
  Future<({List<FlutterNode> nodes, List<String> transcript})> snapshot({String locale = 'pl'}) async {
    final json = await _call(extension, {'includeRects': 'true', 'locale': locale}, 'snapshot');
    try {
      return (
        nodes: [for (final n in json['nodes'] as List) FlutterNode.fromJson(n as Map<String, dynamic>)],
        transcript: [for (final line in json['transcript'] as List) line as String],
      );
    } on Object catch (e) {
      if (e is! FormatException && e is! TypeError) rethrow;
      throw CliFailure('$extension returned an unexpected snapshot: $e');
    }
  }

  /// The in-app WCAG audit; a finding without a node is about the whole screen.
  Future<List<Finding>> audit() async {
    final json = await _call(auditExtension, const {}, 'audit');
    try {
      return [for (final raw in json['findings'] as List) _finding(raw as Map<String, dynamic>)];
    } on Object catch (e) {
      if (e is! FormatException && e is! TypeError) rethrow;
      throw CliFailure('$auditExtension returned an unexpected result: $e');
    }
  }

  static Finding _finding(Map<String, dynamic> json) {
    final node = json['node'] as Map<String, dynamic>?;
    return Finding(
      rule: json['rule'] as String,
      source: 'flutter',
      severity: json['severity'] as String,
      message: json['message'] as String,
      wcag: json['wcag'] as String?,
      flutterId: node?['id'] as int?,
      rect: node == null ? null : A11yRect.fromList(node['rect'] as List),
    );
  }

  Future<void> close() => _service.dispose();
}
