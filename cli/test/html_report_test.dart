import 'dart:convert';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

const _time = '2026-11-07 09:05';

NativeNode _nativeNode(String path, String label, A11yRect rect) => NativeNode(
  path: path,
  nativeType: 'android.widget.Button',
  role: 'button',
  label: label,
  value: '',
  hint: '',
  identifier: '',
  rect: rect,
  focusable: true,
  clickable: true,
  enabled: true,
  selected: false,
  checked: null,
  heading: false,
);

CheckReport _report(
  List<Finding> findings, {
  List<FlutterNode> flutterNodes = const [],
  List<NativeNode> nativeNodes = const [],
  List<String> transcript = const [],
  String app = 'dev.app',
}) => CheckReport(
  flutterNodes: flutterNodes,
  native: NativeTree(
    platform: 'android',
    device: 'emulator-5580',
    app: app,
    screen: const NativeScreen(width: 400, height: 800, scale: 2),
    nodes: nativeNodes,
    issues: const [],
  ),
  matches: const [],
  findings: findings,
  transcript: transcript,
);

Finding _finding(
  String rule, {
  String severity = 'warning',
  String source = 'crosscheck',
  String? message,
  int? flutterId,
  String? nativePath,
  A11yRect? rect,
  String? wcag,
}) => Finding(
  rule: rule,
  source: source,
  severity: severity,
  message: message ?? 'message of $rule',
  flutterId: flutterId,
  nativePath: nativePath,
  rect: rect,
  wcag: wcag,
);

String _render(CheckReport report, {List<int>? screenshot}) =>
    HtmlReport(report, device: 'emulator-5580', time: DateTime(2026, 11, 7, 9, 5), screenshot: screenshot).render();

/// `(class, number)` of every box, in document order.
List<(String, String)> _boxes(String html) => [
  for (final m in RegExp(r'<a class="box (\w+)" href="#g(\d+)"').allMatches(html)) (m[1]!, m[2]!),
];

void main() {
  test('is one UTF-8 HTML document', () {
    final html = _render(_report([]));

    expect(html, startsWith('<!DOCTYPE html>\n'));
    expect(html, contains('<meta charset="utf-8">'));
    expect(html.trimRight(), endsWith('</html>'));
  });

  test('the header names app, platform, device, local time and counts per severity', () {
    final html = _render(
      _report([
        _finding('a', severity: 'error', rect: const A11yRect(0, 0, 1, 1)),
        _finding('b', severity: 'error'),
        _finding('c', rect: const A11yRect(5, 5, 1, 1)),
      ]),
    );

    for (final text in ['>dev.app<', '>android<', '>emulator-5580<', '>$_time<']) {
      expect(html, contains(text));
    }
    expect(html, contains('error: 2'));
    expect(html, contains('warning: 1'));
    expect(html, contains('info: 0'));
  });

  test('boxes sit in percent of the native screen, coloured by worst severity and numbered', () {
    final html = _render(
      _report([
        _finding('w', rect: const A11yRect(40, 80, 100, 200)),
        _finding('e', severity: 'error', rect: const A11yRect(0, 400, 400, 400)),
        _finding('i', severity: 'info', rect: const A11yRect(200, 0, 2, 4)),
      ]),
    );

    expect(_boxes(html), [('error', '1'), ('warning', '2'), ('info', '3')]);
    expect(html, contains('href="#g1" data-group="1" style="left:0.00%;top:50.00%;width:100.00%;height:50.00%"'));
    expect(html, contains('href="#g2" data-group="2" style="left:10.00%;top:10.00%;width:25.00%;height:25.00%"'));
    expect(html, contains('href="#g3" data-group="3" style="left:50.00%;top:0.00%;width:0.50%;height:0.50%"'));
    expect(
      RegExp(r'<span class="badge">(\d+)</span>').allMatches(html).map((m) => m[1]),
      containsAllInOrder(['1', '2', '3']),
    );
  });

  test('the list has one entry per group, numbered like its badge, and the whole screen last', () {
    final html = _render(
      _report([
        _finding('screen-rule', severity: 'error', wcag: '1.3.1'),
        _finding('first', flutterId: 4, rect: const A11yRect(0, 0, 10, 10), wcag: '2.5.8', source: 'flutter'),
        _finding('second', flutterId: 4, severity: 'error', source: 'atf'),
      ]),
    );

    final entries = RegExp(r'<li class="group (\w+)" id="g(\d+)" data-group="(\d+)" tabindex="0">').allMatches(html);
    expect(entries.map((m) => (m[1], m[2], m[3])), [('error', '1', '1')]);
    final group = html.indexOf('id="g1"');
    final screen = html.indexOf('<h3>Whole screen</h3>');
    expect(screen, greaterThan(group));
    int rule(String name) => html.indexOf('<span class="rule">$name</span>');
    expect(rule('first'), allOf(greaterThan(group), lessThan(screen)));
    expect(rule('second'), allOf(greaterThan(rule('first')), lessThan(screen)));
    expect(rule('screen-rule'), greaterThan(screen));
    expect(_boxes(html), [('error', '1')], reason: 'the whole screen has no box');
  });

  test('each finding shows severity, rule, source, WCAG when known and message', () {
    final html = _render(
      _report([
        _finding('target-size', severity: 'error', source: 'flutter', wcag: '2.5.8', message: 'Too small.'),
        _finding('Unknown', source: 'atf', message: 'No reference.'),
      ]),
    );

    expect(
      html,
      contains(
        '<span class="sev error">error</span> <span class="rule">target-size</span> '
        '<span class="source">flutter</span> <span class="wcag">WCAG 2.5.8</span>'
        '<p class="message">Too small.</p>',
      ),
    );
    expect(
      html,
      contains(
        '<span class="sev warning">warning</span> <span class="rule">Unknown</span> '
        '<span class="source">atf</span><p class="message">No reference.</p>',
      ),
    );
  });

  test('each group names its element', () {
    final html = _render(
      _report(
        [
          _finding('a', flutterId: 1, rect: const A11yRect(10, 20, 30, 40)),
          _finding('b', nativePath: '0.5', rect: const A11yRect(1, 2, 3, 4)),
          _finding('c', rect: const A11yRect(5.4, 6.6, 7, 8)),
        ],
        flutterNodes: [const FlutterNode(id: 1, role: 'button', name: 'Usuń', rect: A11yRect(10, 20, 30, 40))],
        nativeNodes: [_nativeNode('0.5', '', const A11yRect(1, 2, 3, 4))],
      ),
    );

    expect(html, contains('<span class="target">button &quot;Usuń&quot; at [10, 20, 30, 40]</span>'));
    expect(html, contains('<span class="target">android.widget.Button &quot;&quot; at [1, 2, 3, 4]</span>'));
    expect(html, contains('<span class="target">at [5.4, 6.6, 7, 8]</span>'));
  });

  test('the transcript is an ordered list', () {
    final html = _render(_report([], transcript: ['Umów wizytę', 'E-mail, Pole edycji']));

    expect(html, contains('<ol class="transcript"><li>Umów wizytę</li><li>E-mail, Pole edycji</li></ol>'));
  });

  test('the screenshot is embedded as a PNG data URI', () {
    final png = fakePng(800, 1600);

    final html = _render(_report([]), screenshot: png);

    expect(html, contains('<img src="data:image/png;base64,${base64Encode(png)}"'));
    expect(html, isNot(contains('aspect-ratio:400 / 800')));
  });

  test('without a screenshot the boxes sit on an empty frame with the screen aspect ratio', () {
    final html = _render(_report([_finding('a', rect: const A11yRect(0, 0, 1, 1))]));

    expect(html, isNot(contains('<img')));
    expect(html, contains('<div class="frame empty" style="aspect-ratio:400 / 800">'));
    expect(_boxes(html), hasLength(1));
  });

  test('app and engine strings are escaped', () {
    final html = _render(
      _report(
        [
          _finding('<b>rule</b>', flutterId: 1, rect: const A11yRect(0, 0, 1, 1), message: '<script>alert(2)</script>'),
          _finding('x', nativePath: '0.1', rect: const A11yRect(9, 9, 1, 1)),
        ],
        flutterNodes: [
          const FlutterNode(id: 1, role: 'button', name: '<script>alert(1)</script>', rect: A11yRect(0, 0, 1, 1)),
        ],
        nativeNodes: [_nativeNode('0.1', '"><script>alert(3)</script>', const A11yRect(9, 9, 1, 1))],
        transcript: ['<script>alert(4)</script>'],
        app: '<i>app</i>',
      ),
    );

    expect(html, isNot(contains('<script>alert')));
    expect(html, isNot(contains('"><script')));
    expect(html, isNot(contains('<b>rule')));
    expect(html, isNot(contains('<i>app')));
    expect('<script'.allMatches(html), hasLength(1), reason: 'only the report script itself');
    for (final n in [1, 2, 3, 4]) {
      expect(html, contains('&lt;script&gt;alert($n)&lt;&#47;script&gt;'));
    }
  });

  test('nothing is loaded from the network; URLs in app text stay inert text', () {
    final html = _render(
      _report([
        _finding(
          'link',
          rect: const A11yRect(0, 0, 1, 1),
          message: 'see http://example.com/help <img src="https://evil.test/x.png"> url(https://evil.test/f.woff)',
        ),
      ]),
      screenshot: fakePng(800, 1600),
    );

    expect(html, isNot(matches(RegExp(r'''(src|href)\s*=\s*["']?\s*(https?:)?//''', caseSensitive: false))));
    expect(html, isNot(matches(RegExp(r'''url\(\s*["']?\s*(https?:)?//''', caseSensitive: false))));
    expect(html, isNot(contains('@import')));
    expect(html, isNot(contains('<link')));
    expect(html, isNot(matches(RegExp(r'<script[^>]*\ssrc', caseSensitive: false))));
    expect(html, contains('see http:&#47;&#47;example.com&#47;help &lt;img src=&quot;https:&#47;&#47;evil.test'));
  });

  test('boxes and list entries share their group number for highlighting', () {
    final html = _render(_report([_finding('a', rect: const A11yRect(0, 0, 1, 1))]));

    expect(html, contains('<a class="box warning" href="#g1" data-group="1"'));
    expect(html, contains('<li class="group warning" id="g1" data-group="1" tabindex="0">'));
    expect(html, contains('prefers-color-scheme: dark'));
  });
}
