import 'package:xml/xml.dart';

/// Parses OOXML styles.xml to map style IDs to text properties.
class DocxStyleParser {
  final Map<String, Map<String, String>> _styles = {};

  void parse(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final styles = document.findAllElements('w:style');

    for (var style in styles) {
      final styleId = style.getAttribute('w:styleId');
      if (styleId == null) continue;

      final rPr = style.getElement('w:rPr');
      if (rPr != null) {
        _styles[styleId] = {
          'size': rPr.getElement('w:sz')?.getAttribute('w:val') ?? '12',
          'bold': rPr.getElement('w:b') != null ? 'true' : 'false',
        };
      }
    }
  }

  Map<String, String>? getStyle(String styleId) => _styles[styleId];
}
