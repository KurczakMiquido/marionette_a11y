import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matcher/src/expect/async_matcher.dart'; // ignore: implementation_imports

import '../a11y_snapshot.dart';

/// Matches the screen-reader transcript of the live semantics tree against a golden text file.
///
/// With `flutter test --update-goldens` the file is (re)written instead.
AsyncMatcher matchesA11yTranscript(String path, {String locale = 'pl'}) => _TranscriptMatcher(path, locale);

class _TranscriptMatcher extends AsyncMatcher {
  _TranscriptMatcher(this.path, this.locale);

  final String path;
  final String locale;

  @override
  Description describe(Description description) => description.add('matches the a11y transcript golden $path');

  @override
  Future<String?> matchAsync(covariant WidgetTester tester) async {
    final actual = A11ySnapshot.capture().transcript(locale: locale).map((line) => '$line\n').join();
    final file = File(_resolve());

    if (autoUpdateGoldenFiles) {
      // Sync IO: async file calls never complete inside testWidgets' fake-async zone.
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(actual);
      return null;
    }
    if (!file.existsSync()) return 'golden $path not found; run flutter test --update-goldens';

    final expected = file.readAsStringSync().replaceAll('\r\n', '\n');
    if (expected == actual) return null;
    if (expected.trimRight() == actual.trimRight()) {
      return 'transcript differs from $path only in trailing whitespace or the final newline; '
          'run flutter test --update-goldens to rewrite it';
    }
    return 'transcript differs from $path (- expected, + actual):\n${_diff(_lines(expected), _lines(actual))}';
  }

  // Same rule as matchesGoldenFile: relative to the test file's directory when the comparator knows it.
  String _resolve() {
    final comparator = goldenFileComparator;
    if (comparator is LocalFileComparator) return comparator.basedir.resolve(path).toFilePath();
    return Uri.file('${Directory.current.path}/').resolve(path).toFilePath();
  }

  static List<String> _lines(String text) => text.isEmpty ? [] : text.trimRight().split('\n');

  /// Line diff from the longest common subsequence, so one inserted line does not mark the rest as changed.
  static String _diff(List<String> a, List<String> b) {
    final lcs = [for (var i = 0; i <= a.length; i++) List.filled(b.length + 1, 0)];
    for (var i = a.length - 1; i >= 0; i--) {
      for (var j = b.length - 1; j >= 0; j--) {
        lcs[i][j] = a[i] == b[j]
            ? lcs[i + 1][j + 1] + 1
            : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }
    final out = <String>[];
    var i = 0, j = 0;
    while (i < a.length || j < b.length) {
      if (i < a.length && j < b.length && a[i] == b[j]) {
        out.add('  ${a[i]}');
        i++;
        j++;
      } else if (j >= b.length || (i < a.length && lcs[i + 1][j] >= lcs[i][j + 1])) {
        out.add('-${a[i++]}');
      } else {
        out.add('+${b[j++]}');
      }
    }
    return out.join('\n');
  }
}
