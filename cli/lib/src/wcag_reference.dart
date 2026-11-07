/// The WCAG 2.2 success criterion a native check relates to (docs/specs/report-and-testing.md, section 3).
class WcagReference {
  static const crosscheck = '4.1.2';

  static const _byCheck = {
    'atf': {
      'TouchTargetSizeCheck': '2.5.8',
      'TextContrastCheck': '1.4.3',
      'ImageContrastCheck': '1.4.11',
      'TextSizeCheck': '1.4.4',
      'TraversalOrderCheck': '1.3.2',
      'LinkPurposeUnclearCheck': '2.4.4',
      'DuplicateSpeakableTextCheck': '2.4.6',
      'SpeakableTextPresentCheck': '4.1.2',
      'EditableContentDescCheck': '4.1.2',
      'RedundantDescriptionCheck': '4.1.2',
      'DuplicateClickableBoundsCheck': '4.1.2',
      'ClickableSpanCheck': '4.1.2',
      'UnexposedTextCheck': '4.1.2',
      'ClassNameCheck': '4.1.2',
    },
    'apple': {
      'contrast': '1.4.3',
      'hitRegion': '2.5.8',
      'dynamicType': '1.4.4',
      'textClipped': '1.4.4',
      'elementDetection': '4.1.2',
      'sufficientElementDescription': '4.1.2',
      'trait': '4.1.2',
    },
  };

  /// The criterion for a native issue's [source] and [check], or null when none is mapped.
  static String? forNative(String source, String check) => _byCheck[source]?[check];
}
