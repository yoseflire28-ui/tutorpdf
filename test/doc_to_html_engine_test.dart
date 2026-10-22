import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorpdf/services/doc_to_html_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocToHtmlEngine', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('doc_to_html_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {
          // Ignore cleanup races in the test environment.
        }
      }
    });

    test('renders styled DOCX content into HTML', () async {
      final docxPath = File('${tempDir.path}/sample.docx');
      final archive = Archive();
      final docxContent = utf8.encode(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:i/><w:u w:val="single"/><w:color w:val="FF0000"/><w:highlight w:val="yellow"/><w:sz w:val="28"/><w:rFonts w:ascii="Arial"/><w:spacing w:val="120"/><w:position w:val="10"/></w:rPr><w:t>Hello</w:t></w:r></w:p></w:body></w:document>',
      );
      archive.addFile(ArchiveFile('word/document.xml', docxContent.length, docxContent));
      final bytes = ZipEncoder().encode(archive)!;
      docxPath.writeAsBytesSync(bytes);

      final html = await DocToHtmlEngine().convertToHtml(docxPath.path);

      expect(html, contains('<p'));
      expect(html, contains('font-weight: bold'));
      expect(html, contains('font-style: italic'));
      expect(html, contains('text-decoration: underline'));
      expect(html, contains('font-family: Arial'));
      expect(html, contains('color: #ff0000'));
    });

    test('renders DOCX tables as HTML tables with header styling', () async {
      final docxPath = File('${tempDir.path}/table.docx');
      final archive = Archive();
      final docxContent = utf8.encode(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>'
        '<w:p><w:r><w:t>Before table</w:t></w:r></w:p>'
        '<w:tbl>'
        '<w:tblPr><w:tblBorders/></w:tblPr>'
        '<w:tblGrid><w:gridCol/><w:gridCol/></w:tblGrid>'
        '<w:tr>'
        '<w:tc><w:p><w:r><w:t>Header 1</w:t></w:r></w:p></w:tc>'
        '<w:tc><w:p><w:r><w:t>Header 2</w:t></w:r></w:p></w:tc>'
        '</w:tr>'
        '<w:tr>'
        '<w:tc><w:p><w:r><w:t>Row 1</w:t></w:r></w:p></w:tc>'
        '<w:tc><w:p><w:r><w:t>Row 2</w:t></w:r></w:p></w:tc>'
        '</w:tr>'
        '</w:tbl>'
        '<w:p><w:r><w:t>After table</w:t></w:r></w:p>'
        '</w:body></w:document>',
      );
      archive.addFile(ArchiveFile('word/document.xml', docxContent.length, docxContent));
      final bytes = ZipEncoder().encode(archive)!;
      docxPath.writeAsBytesSync(bytes);

      final html = await DocToHtmlEngine().convertToHtml(docxPath.path);

      expect(html, contains('<table'));
      expect(html, contains('<th'));
      expect(html, contains('border-collapse: collapse'));
      expect(html, contains('Header 1'));
      expect(html, contains('Row 1'));
    });

    test('renders slide containers for PPTX content', () async {
      final pptxPath = File('${tempDir.path}/sample.pptx');
      final archive = Archive();
      final slide1Content = utf8.encode(
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:cSld><p:spTree><p:sp><p:txBody><a:body><a:p><a:r><a:t>First slide</a:t></a:r></a:p></a:body></p:txBody></p:sp></p:spTree></p:cSld></p:sld>',
      );
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Content.length, slide1Content));

      final slide2Content = utf8.encode(
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:cSld><p:spTree><p:sp><p:txBody><a:body><a:p><a:r><a:t>Second slide</a:t></a:r></a:p></a:body></p:txBody></p:sp></p:spTree></p:cSld></p:sld>',
      );
      archive.addFile(ArchiveFile('ppt/slides/slide2.xml', slide2Content.length, slide2Content));
      final bytes = ZipEncoder().encode(archive)!;
      pptxPath.writeAsBytesSync(bytes);

      final html = await DocToHtmlEngine().convertToHtml(pptxPath.path);

      expect(html, contains('class="slide"'));
      expect(html, contains('First slide'));
      expect(html, contains('Second slide'));
    });
  });
}
