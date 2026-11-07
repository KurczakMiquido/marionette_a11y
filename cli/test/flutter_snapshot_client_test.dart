import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('webSocketUri', () {
    test('keeps a ws URI', () {
      expect(
        FlutterSnapshotClient.webSocketUri('ws://127.0.0.1:5000/abc=/ws').toString(),
        'ws://127.0.0.1:5000/abc=/ws',
      );
    });

    test('turns the http URI that apps log into the ws one', () {
      expect(
        FlutterSnapshotClient.webSocketUri('http://127.0.0.1:5000/abc=/').toString(),
        'ws://127.0.0.1:5000/abc=/ws',
      );
      expect(
        FlutterSnapshotClient.webSocketUri('http://127.0.0.1:5000/abc=').toString(),
        'ws://127.0.0.1:5000/abc=/ws',
      );
    });

    test('rejects anything else', () {
      expect(() => FlutterSnapshotClient.webSocketUri('127.0.0.1:5000'), throwsA(isA<CliFailure>()));
    });
  });

  test('fetches the snapshot with rects from the isolate that exposes the extension', () async {
    final client = await FlutterSnapshotClient.connect(await startFakeApp());
    addTearDown(client.close);

    final nodes = await client.snapshot();

    expect([for (final n in nodes) n.toJson()], fixture('flutter_snapshot')['nodes']);
  });

  test('fails clearly when no isolate exposes the extension', () async {
    final uri = await startFakeApp(withExtension: false);

    expect(
      FlutterSnapshotClient.connect(uri),
      throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('ext.flutter.a11y.snapshot'))),
    );
  });

  test('fails clearly when nothing listens at the URI', () {
    expect(
      FlutterSnapshotClient.connect('ws://127.0.0.1:9/nothing/ws'),
      throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('VM service'))),
    );
  });
}
