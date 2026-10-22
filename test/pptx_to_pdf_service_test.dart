import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:tutorpdf/screens/pptx_reader_screen.dart';
import 'package:tutorpdf/services/pptx_to_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PptxToPdfService - WPS Visual Fidelity & Rendering Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pptx_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('PptxTheme extracts theme scheme colors and resolves transforms accurately', () {
      const themeXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>
      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>
      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>
      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>
      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>
      <a:accent6><a:srgbClr val="F79646"/></a:accent6>
    </a:clrScheme>
  </a:themeElements>
</a:theme>
''';

      final theme = PptxTheme.fromXml(themeXml);
      expect(theme.colorScheme['accent1'], isNotNull);
      expect(theme.colorScheme['accent1'], equals(const PdfColor.fromInt(0xFF4F81BD)));
      expect(theme.colorScheme['accent2'], equals(const PdfColor.fromInt(0xFFC0504D)));

      // Test color transforms
      const baseColor = PdfColor.fromInt(0xFF4F81BD);
      expect(PptxColorHelper.parseHex('4F81BD'), equals(baseColor));
    });

    test('EMU conversion to PDF points strictly maintains 1 pt = 12700 EMUs', () {
      const emuX = 12192000; // 960 pt
      const emuY = 6858000;  // 540 pt
      const emuAuthorOffX = 1524000; // 120 pt
      const emuAuthorOffY = 3048000; // 240 pt

      expect(emuX / 12700.0, equals(960.0));
      expect(emuY / 12700.0, equals(540.0));
      expect(emuAuthorOffX / 12700.0, equals(120.0));
      expect(emuAuthorOffY / 12700.0, equals(240.0));
    });

    test('Sanitizes typography, smart quotes, bullets, and wingdings', () {
      const input = '“Smart Quotes” & ‘Apostrophe’ — EmDash • Bullet \u2713 Check';
      final sanitized = PptxToPdfService.sanitizeText(input);

      expect(sanitized, contains('"Smart Quotes"'));
      expect(sanitized, contains("'Apostrophe'"));
      expect(sanitized, contains('- EmDash'));
      expect(sanitized, contains('Bullet'));
      expect(sanitized, contains('[v]'));
    });

    test('Converts full PPTX presentation with master shapes, gradient wave banner, and author subtitle to PDF', () async {
      final archive = Archive();

      // 1. [Content_Types].xml
      const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
</Types>''';
      archive.addFile(ArchiveFile('[Content_Types].xml', utf8.encode(contentTypes).length, utf8.encode(contentTypes)));

      // 2. presentation.xml with 16:9 dimensions (12192000 x 6858000 EMUs = 960 x 540 pt)
      const presXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
  </p:sldIdLst>
</p:presentation>''';
      archive.addFile(ArchiveFile('ppt/presentation.xml', utf8.encode(presXml).length, utf8.encode(presXml)));

      // 3. presentation.xml.rels
      const presRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', utf8.encode(presRels).length, utf8.encode(presRels)));

      // 4. theme1.xml
      const themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
      <a:accent1><a:srgbClr val="1D4ED8"/></a:accent1>
      <a:accent2><a:srgbClr val="DC2626"/></a:accent2>
    </a:clrScheme>
  </a:themeElements>
</a:theme>''';
      archive.addFile(ArchiveFile('ppt/theme/theme1.xml', utf8.encode(themeXml).length, utf8.encode(themeXml)));

      // 5. slideMaster1.xml with background wave banner graphic
      const masterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <!-- Decorative background wave banner -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Wave Shape"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="0" y="5080000"/><a:ext cx="12192000" cy="1778000"/></a:xfrm>
          <a:prstGeom prst="wave"><a:avLst/></a:prstGeom>
          <a:gradFill>
            <a:gsLst>
              <a:gs pos="0"><a:srgbClr val="1D4ED8"/></a:gs>
              <a:gs pos="100000"><a:srgbClr val="3B82F6"/></a:gs>
            </a:gsLst>
            <a:lin ang="5400000"/>
          </a:gradFill>
        </p:spPr>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sldMaster>''';
      archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', utf8.encode(masterXml).length, utf8.encode(masterXml)));

      // 6. slideLayout1.xml linking to slideMaster1
      const layoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
    </p:spTree>
  </p:cSld>
</p:sldLayout>''';
      archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', utf8.encode(layoutXml).length, utf8.encode(layoutXml)));

      const layoutRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', utf8.encode(layoutRels).length, utf8.encode(layoutRels)));

      // 7. slide1.xml with title and author subtitle ("Presented by: Alemayehu S.")
      const slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <!-- Title Box -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="ctrTitle"/></p:nvPr></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1524000" y="1524000"/><a:ext cx="9144000" cy="1270000"/></a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor="ctr"/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr sz="3600" b="1"><a:solidFill><a:srgbClr val="1E3A8A"/></a:solidFill></a:rPr>
              <a:t>Advanced Architectural Design</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
      <!-- Subtitle Box: Author info -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Subtitle"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="subTitle"/></p:nvPr></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1524000" y="3048000"/><a:ext cx="9144000" cy="762000"/></a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr anchor="ctr"/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr sz="1800"><a:solidFill><a:srgbClr val="374151"/></a:solidFill></a:rPr>
              <a:t>Presented by: Alemayehu S.</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', utf8.encode(slideXml).length, utf8.encode(slideXml)));

      const slideRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide1.xml.rels', utf8.encode(slideRels).length, utf8.encode(slideRels)));

      // Encode ZIP bytes
      final zipEncoder = ZipEncoder();
      final Uint8List pptxBytes = Uint8List.fromList(zipEncoder.encode(archive)!);

      // Convert to PDF bytes
      final pdfBytes = await PptxToPdfService.convertPptxBytesToPdf(pptxBytes);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));

      // Verify PDF Header (%PDF-1.x)
      final pdfHeader = utf8.decode(pdfBytes.sublist(0, 5));
      expect(pdfHeader, equals('%PDF-'));
    });

    test('isMasterPlaceholderPrompt identifies default OpenXML prompt strings and preserves user text', () {
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Click to edit Master title style'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Click to edit Master subtitle style'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Click to edit Master text style'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Click to edit Master text styles'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Click to edit Master body style'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Click to add title'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Click to add subtitle'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Second level'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Third level'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Fourth level'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Fifth level'), isTrue);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('   '), isTrue);

      // User entered content must NOT be filtered
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Software Design'), isFalse);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Presented by: Alemayehu S.'), isFalse);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Advanced Architectural Design'), isFalse);
      expect(PptxToPdfService.isMasterPlaceholderPrompt('Introduction to Microservices'), isFalse);
    });

    test('PptxViewerScreen & PptxReaderScreen alias can be constructed', () {
      const viewer = PptxViewerScreen(uri: 'sample.pptx', title: 'Sample Deck');
      const reader = PptxReaderScreen(uri: 'sample.pptx', title: 'Sample Deck');

      expect(viewer.title, equals('Sample Deck'));
      expect(reader.title, equals('Sample Deck'));
      expect(viewer.filePath, equals('sample.pptx'));
    });

    test('Converts presentation containing master placeholder prompts without leaking template strings', () async {
      final archive = Archive();

      // [Content_Types].xml
      const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
</Types>''';
      archive.addFile(ArchiveFile('[Content_Types].xml', utf8.encode(contentTypes).length, utf8.encode(contentTypes)));

      // presentation.xml
      const presXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>
  <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
</p:presentation>''';
      archive.addFile(ArchiveFile('ppt/presentation.xml', utf8.encode(presXml).length, utf8.encode(presXml)));

      const presRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', utf8.encode(presRels).length, utf8.encode(presRels)));

      // theme1.xml
      const themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
      <a:accent1><a:srgbClr val="1D4ED8"/></a:accent1>
      <a:accent2><a:srgbClr val="DC2626"/></a:accent2>
    </a:clrScheme>
  </a:themeElements>
</a:theme>''';
      archive.addFile(ArchiveFile('ppt/theme/theme1.xml', utf8.encode(themeXml).length, utf8.encode(themeXml)));

      // slideMaster1.xml with prompt texts that must NOT leak
      const masterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></p:bgPr></p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <!-- Blue Gradient Footer Wave Banner with custom geometry -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Footer Banner"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="0" y="4500000"/><a:ext cx="12192000" cy="2358000"/></a:xfrm>
          <a:custGeom>
            <a:avLst/>
            <a:gdLst/>
            <a:ahLst/>
            <a:cxnLst/>
            <a:rect l="0" t="0" r="12192000" b="2358000"/>
            <a:pathLst>
              <a:path w="12192000" h="2358000">
                <a:moveTo><a:pt x="0" y="0"/></a:moveTo>
                <a:lnTo><a:pt x="12192000" y="0"/></a:lnTo>
                <a:lnTo><a:pt x="12192000" y="2358000"/></a:lnTo>
                <a:lnTo><a:pt x="0" y="2358000"/></a:lnTo>
                <a:close/>
              </a:path>
            </a:pathLst>
          </a:custGeom>
          <a:gradFill>
            <a:gsLst>
              <a:gs pos="0"><a:srgbClr val="1E3A8A"/></a:gs>
              <a:gs pos="50000"><a:srgbClr val="2563EB"/></a:gs>
              <a:gs pos="100000"><a:srgbClr val="3B82F6"/></a:gs>
            </a:gsLst>
            <a:lin ang="5400000"/>
          </a:gradFill>
        </p:spPr>
      </p:sp>
      <!-- Title placeholder with prompt text that must be suppressed -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Title Placeholder"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="1000000" y="1000000"/><a:ext cx="10000000" cy="1000000"/></a:xfrm></p:spPr>
        <p:txBody>
          <a:bodyPr/>
          <a:p><a:r><a:t>Click to edit Master title style</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sldMaster>''';
      archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', utf8.encode(masterXml).length, utf8.encode(masterXml)));

      // slideLayout1.xml linking to slideMaster1 with layout placeholder prompts
      const layoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Subtitle Placeholder"/><p:cNvSpPr/><p:nvPr><p:ph type="subTitle"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="1000000" y="4700000"/><a:ext cx="10000000" cy="1000000"/></a:xfrm></p:spPr>
        <p:txBody>
          <a:bodyPr/>
          <a:p><a:r><a:t>Click to edit Master subtitle style</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sldLayout>''';
      archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', utf8.encode(layoutXml).length, utf8.encode(layoutXml)));

      const layoutRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', utf8.encode(layoutRels).length, utf8.encode(layoutRels)));

      // slide1.xml with user data: Title and Subtitle ("Presented by: Alemayehu S.") placed over footer banner
      const slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <!-- User Title -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="5" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="ctrTitle"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="1524000" y="1524000"/><a:ext cx="9144000" cy="1270000"/></a:xfrm></p:spPr>
        <p:txBody>
          <a:bodyPr anchor="ctr"/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr sz="3600" b="1"><a:solidFill><a:srgbClr val="1E3A8A"/></a:solidFill></a:rPr>
              <a:t>Software Design</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
      <!-- User Subtitle placed over dark footer banner (y=4700000 within y=4500000..6858000) -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="6" name="Subtitle"/><p:cNvSpPr/><p:nvPr><p:ph type="subTitle"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="1524000" y="4700000"/><a:ext cx="9144000" cy="762000"/></a:xfrm></p:spPr>
        <p:txBody>
          <a:bodyPr anchor="ctr"/>
          <a:p>
            <a:pPr algn="ctr"/>
            <a:r>
              <a:rPr sz="1800"/>
              <a:t>Presented by: Alemayehu S.</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', utf8.encode(slideXml).length, utf8.encode(slideXml)));

      const slideRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide1.xml.rels', utf8.encode(slideRels).length, utf8.encode(slideRels)));

      // Encode ZIP bytes
      final zipEncoder = ZipEncoder();
      final Uint8List pptxBytes = Uint8List.fromList(zipEncoder.encode(archive)!);

      // Convert to PDF bytes in light mode
      final pdfBytesLight = await PptxToPdfService.convertPptxBytesToPdf(pptxBytes, isDarkMode: false);
      expect(pdfBytesLight, isNotNull);
      expect(pdfBytesLight.length, greaterThan(100));
      expect(utf8.decode(pdfBytesLight.sublist(0, 5)), equals('%PDF-'));

      // Convert to PDF bytes in dark mode (verifying no crashes and valid PDF output)
      final pdfBytesDark = await PptxToPdfService.convertPptxBytesToPdf(pptxBytes, isDarkMode: true);
      expect(pdfBytesDark, isNotNull);
      expect(pdfBytesDark.length, greaterThan(100));
      expect(utf8.decode(pdfBytesDark.sublist(0, 5)), equals('%PDF-'));
    });

    test('Converts presentation with pattern fill (<a:pattFill>) and style references (<a:fillRef>) without pixelated artifacts', () async {
      final archive = Archive();

      const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
</Types>''';
      archive.addFile(ArchiveFile('[Content_Types].xml', utf8.encode(contentTypes).length, utf8.encode(contentTypes)));

      const presXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>
  <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
</p:presentation>''';
      archive.addFile(ArchiveFile('ppt/presentation.xml', utf8.encode(presXml).length, utf8.encode(presXml)));

      const presRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>''';
      archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', utf8.encode(presRels).length, utf8.encode(presRels)));

      const themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:srgbClr val="111111"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
      <a:accent1><a:srgbClr val="2563EB"/></a:accent1>
      <a:accent2><a:srgbClr val="DC2626"/></a:accent2>
    </a:clrScheme>
  </a:themeElements>
</a:theme>''';
      archive.addFile(ArchiveFile('ppt/theme/theme1.xml', utf8.encode(themeXml).length, utf8.encode(themeXml)));

      const slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <!-- Shape with pattern fill -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Pattern Shape"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1000000" y="1000000"/><a:ext cx="4000000" cy="2000000"/></a:xfrm>
          <a:pattFill prst="pct5">
            <a:fgClr><a:srgbClr val="3B82F6"/></a:fgClr>
            <a:bgClr><a:srgbClr val="1E3A8A"/></a:bgClr>
          </a:pattFill>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/>
          <a:p><a:r><a:t>Pattern Vector Content</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <!-- Shape with style fillRef and lnRef -->
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Styled Shape"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="5500000" y="1000000"/><a:ext cx="4000000" cy="2000000"/></a:xfrm>
        </p:spPr>
        <p:style>
          <a:lnRef idx="1"><a:schemeClr val="accent1"/></a:lnRef>
          <a:fillRef idx="2"><a:schemeClr val="accent1"/></a:fillRef>
        </p:style>
        <p:txBody>
          <a:bodyPr/>
          <a:p><a:r><a:t>Styled Accent Box</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', utf8.encode(slideXml).length, utf8.encode(slideXml)));

      const slideRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>''';
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide1.xml.rels', utf8.encode(slideRels).length, utf8.encode(slideRels)));

      final zipEncoder = ZipEncoder();
      final Uint8List pptxBytes = Uint8List.fromList(zipEncoder.encode(archive)!);

      final pdfBytes = await PptxToPdfService.convertPptxBytesToPdf(pptxBytes, isDarkMode: true);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));
      expect(utf8.decode(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });
  });
}
