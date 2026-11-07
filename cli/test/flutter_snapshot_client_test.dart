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

    test('does not append a second ws to an http URI that already ends in ws', () {
      expect(
        FlutterSnapshotClient.webSocketUri('http://127.0.0.1:5000/abc=/ws').toString(),
        'ws://127.0.0.1:5000/abc=/ws',
      );
      expect(
        FlutterSnapshotClient.webSocketUri('https://127.0.0.1:5000/abc=/ws/').toString(),
        'wss://127.0.0.1:5000/abc=/ws',
      );
    });

    test('rejects anything else', () {
      expect(() => FlutterSnapshotClient.webSocketUri('127.0.0.1:5000'), throwsA(isA<CliFailure>()));
    });
  });

  test('fetches the snapshot with rects from the isolate that exposes the extension', () async {
    final client = await FlutterSnapshotClient.connect(await startFakeApp());
    addTearDown(client.close);

    final snapshot = await client.snapshot();

    expect([for (final n in snapshot.nodes) n.toJson()], fixture('flutter_snapshot')['nodes']);
    expect(snapshot.transcript, fixture('flutter_snapshot')['transcript']);
  });

  test('asks for the transcript in the given locale', () async {
    final client = await FlutterSnapshotClient.connect(await startFakeApp());
    addTearDown(client.close);

    expect((await client.snapshot()).transcript.first, isNot(endsWith('[en]')));
    expect((await client.snapshot(locale: 'en')).transcript, everyElement(endsWith(' [en]')));
  });

  group('audit', () {
    test('maps the recorded in-app findings to flutter findings', () async {
      final client = await FlutterSnapshotClient.connect(await startFakeApp());
      addTearDown(client.close);
      final recorded = (fixture('flutter_audit')['findings'] as List).cast<Map<String, dynamic>>();

      final findings = await client.audit();

      expect(findings, hasLength(recorded.length));
      final first = findings.first;
      expect(first.source, 'flutter');
      expect(first.rule, recorded.first['rule']);
      expect(first.severity, recorded.first['severity']);
      expect(first.message, recorded.first['message']);
      expect(first.wcag, recorded.first['wcag']);
      final node = recorded.first['node'] as Map<String, dynamic>;
      expect(first.flutterId, node['id']);
      expect(first.rect, A11yRect.fromList(node['rect'] as List));
      expect(first.nativePath, isNull);
    });

    test('a screen-level finding has neither flutterId nor rect', () async {
      final client = await FlutterSnapshotClient.connect(await startFakeApp());
      addTearDown(client.close);

      final screenLevel = (await client.audit()).singleWhere((f) => f.rule == 'no-heading');

      expect(screenLevel.flutterId, isNull);
      expect(screenLevel.rect, isNull);
      expect(screenLevel.toJson().keys, isNot(anyOf(contains('flutterId'), contains('rect'))));
    });
  });

  test('a call the app never answers fails after the timeout, naming the call', () async {
    final client = await FlutterSnapshotClient.connect(
      await startFakeApp(hangAudit: true),
      callTimeout: const Duration(milliseconds: 300),
    );
    addTearDown(client.close);

    expect(
      client.audit(),
      throwsA(
        isA<CliFailure>().having(
          (e) => e.message,
          'message',
          'VM service did not answer ext.flutter.a11y.audit within 0.3 s; is the app paused in a debugger?',
        ),
      ),
    );
  });

  test('the call timeout is 30 s unless a test shortens it', () {
    expect(FlutterSnapshotClient.defaultCallTimeout, const Duration(seconds: 30));
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
