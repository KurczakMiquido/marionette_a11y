import 'dart:convert';

import 'html_report_assets.dart';
import 'models/a11y_rect.dart';
import 'models/check_report.dart';
import 'models/finding.dart';
import 'models/finding_group.dart';

/// Renders a [CheckReport] as one self-contained HTML page: header, the screenshot with a numbered box per finding
/// group, the findings and the transcript.
class HtmlReport {
  const HtmlReport(this.report, {required this.device, required this.time, this.screenshot, this.locale = 'pl'});

  static const _escape = HtmlEscape();

  final CheckReport report;

  /// The device the check ran on, as given to the CLI; the probe does not always report one.
  final String device;

  /// When the check ran; shown in local time.
  final DateTime time;

  /// PNG of the screen; without it the boxes sit on an empty frame.
  final List<int>? screenshot;

  /// Language of the transcript (`pl` or `en`), as given to `--locale`; marks it up for screen readers (WCAG 3.1.2).
  final String locale;

  String render() {
    final groups = FindingGroup.of(report);
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Accessibility report: ${_e(report.native.app)}</title>
<style>$htmlReportCss</style>
</head>
<body>
${_header()}
<main>
${_screen(groups)}
${_findings(groups)}
${_transcript()}
</main>
<script>$htmlReportScript</script>
</body>
</html>
''';
  }

  String _header() {
    final native = report.native;
    final meta = {'App': native.app, 'Platform': native.platform, 'Device': device, 'Date': _localTime()};
    final counts = [
      for (final s in Finding.severities)
        '<span class="sev $s">$s: ${report.findings.where((f) => f.severity == s).length}</span>',
    ];
    return '''
<header>
<h1>Accessibility report</h1>
<dl class="meta">${[for (final e in meta.entries) '<div><dt>${e.key}</dt><dd>${_e(e.value)}</dd></div>'].join()}</dl>
<p class="counts">${counts.join(' ')}</p>
</header>''';
  }

  String _localTime() {
    String two(int v) => v.toString().padLeft(2, '0');
    final t = time.toLocal();
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  String _screen(List<FindingGroup> groups) {
    final screen = report.native.screen;
    final png = screenshot;
    // Unitless width over height; the stylesheet caps the frame's width so its height fits the window.
    final ratio = '--ar:${_number(double.parse((screen.width / screen.height).toStringAsFixed(4)))}';
    final frame = png == null
        ? '<div class="frame empty" style="aspect-ratio:${_number(screen.width)} / ${_number(screen.height)};$ratio">'
        : '<div class="frame" style="$ratio"><img src="data:image/png;base64,${base64Encode(png)}" alt="Screenshot of the checked screen">';
    final boxes = [
      for (final g in groups)
        if (g.rect case final rect?)
          '<a class="box ${_class(g.severity)}" href="#g${g.number}" data-group="${g.number}" '
              'style="left:${_percent(rect.left / screen.width)};top:${_percent(rect.top / screen.height)};'
              'width:${_percent(rect.width / screen.width)};height:${_percent(rect.height / screen.height)}" '
              'aria-label="${g.number}: ${_e(g.severity)}, ${_e(_target(g))}"><span class="badge">${g.number}</span></a>',
    ];
    return '<section class="screen" aria-label="Screen">\n$frame\n${boxes.join('\n')}\n</div>\n</section>';
  }

  String _findings(List<FindingGroup> groups) {
    final entries = [
      for (final g in groups)
        if (g.number case final n?)
          '<li class="group ${_class(g.severity)}" id="g$n" data-group="$n" tabindex="0">'
              '<h3><span class="badge">$n</span> <span class="target">${_e(_target(g))}</span></h3>'
              '${_items(g.findings)}</li>',
    ];
    final screenLevel = groups.where((g) => g.number == null).firstOrNull;
    return [
      '<section class="findings">',
      '<h2>Findings</h2>',
      if (groups.isEmpty) '<p class="none">No findings.</p>',
      if (entries.isNotEmpty) '<ol class="groups">\n${entries.join('\n')}\n</ol>',
      if (screenLevel != null)
        '<section class="group ${_class(screenLevel.severity)}"><h3>Whole screen</h3>${_items(screenLevel.findings)}</section>',
      '</section>',
    ].join('\n');
  }

  String _items(List<Finding> findings) {
    final items = [
      for (final f in findings)
        '<li><span class="sev ${_class(f.severity)}">${_e(f.severity)}</span> <span class="rule">${_e(f.rule)}</span> '
            '<span class="source">${_e(f.source)}</span>'
            '${f.wcag == null ? '' : ' <span class="wcag">WCAG ${_e(f.wcag!)}</span>'}'
            '<p class="message">${_e(f.message)}</p></li>',
    ];
    return '<ul class="items">${items.join()}</ul>';
  }

  String _transcript() {
    final lines = report.transcript;
    final body = lines.isEmpty
        ? '<p class="none">Nothing is announced.</p>'
        : '<ol class="transcript" lang="${_e(locale)}">${[for (final line in lines) '<li>${_e(line)}</li>'].join()}</ol>';
    return '<section class="speech">\n<h2>Transcript</h2>\n$body\n</section>';
  }

  /// What the group is about, e.g. `button "Usuń" at [355, 164, 16, 16]`.
  String _target(FindingGroup g) {
    final rect = g.rect;
    final at = rect == null ? '' : 'at ${_format(rect)}';
    final flutterId = g.flutterId;
    final nativePath = g.nativePath;
    String? element;
    if (flutterId != null) {
      final node = report.flutterNodes.where((n) => n.id == flutterId).firstOrNull;
      element = node == null ? 'Flutter node $flutterId' : '${node.role} "${node.name}"';
    } else if (nativePath != null) {
      final node = report.native.nodes.where((n) => n.path == nativePath).firstOrNull;
      element = node == null ? 'native node $nativePath' : '${node.nativeType} "${node.label}"';
    }
    return [?element, if (at.isNotEmpty) at].join(' ');
  }

  /// Only known severities become class names; anything else is drawn as info.
  static String _class(String severity) => Finding.severities.contains(severity) ? severity : 'info';

  static String _e(String text) => _escape.convert(text);

  static String _percent(double fraction) => '${(fraction * 100).toStringAsFixed(2)}%';

  static String _format(A11yRect r) => '[${r.toList().map(_number).join(', ')}]';

  static String _number(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
