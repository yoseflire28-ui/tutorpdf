import 'package:xml/xml.dart';
import 'package:archive/archive.dart';
import 'docx_page_model.dart';

/// DOCX Header/Footer Parser
/// Parses headers, footers, dynamic page number fields (<w:fldSimple w:instr="PAGE">) and text runs from DOCX documents.
class DocxHeaderFooterParser {
  final Archive archive;
  final Map<String, String> docRels;

  DocxHeaderFooterParser({
    required this.archive,
    required this.docRels,
  });

  /// Parse header references from section properties (<w:sectPr>)
  List<HeaderFooterReference> parseHeaderReferences(XmlElement sectPr) {
    final references = <HeaderFooterReference>[];
    
    for (var headerRef in sectPr.findAllElements('w:headerReference')) {
      final rId = headerRef.getAttribute('r:id');
      final type = headerRef.getAttribute('w:type'); // even, odd, first, default
      
      if (rId != null && docRels.containsKey(rId)) {
        final headerPath = docRels[rId]!;
        references.add(HeaderFooterReference(
          rId: rId,
          path: headerPath,
          type: type ?? 'default',
          isHeader: true,
        ));
      }
    }
    
    return references;
  }

  /// Parse footer references from section properties (<w:sectPr>)
  List<HeaderFooterReference> parseFooterReferences(XmlElement sectPr) {
    final references = <HeaderFooterReference>[];
    
    for (var footerRef in sectPr.findAllElements('w:footerReference')) {
      final rId = footerRef.getAttribute('r:id');
      final type = footerRef.getAttribute('w:type'); // even, odd, first, default
      
      if (rId != null && docRels.containsKey(rId)) {
        final footerPath = docRels[rId]!;
        references.add(HeaderFooterReference(
          rId: rId,
          path: footerPath,
          type: type ?? 'default',
          isHeader: false,
        ));
      }
    }
    
    return references;
  }

  /// Load header content from header XML file as DocxHeaderFooter
  DocxHeaderFooter? loadHeader(String headerPath, int index, {int pageNumber = 1}) {
    final headerFile = archive.findFile(headerPath);
    if (headerFile == null) return null;
    
    try {
      final content = String.fromCharCodes(headerFile.content);
      final doc = XmlDocument.parse(content);
      return _parseHeaderFooterDoc(doc, index, pageNumber: pageNumber);
    } catch (e) {
      return null;
    }
  }

  /// Load footer content from footer XML file as DocxHeaderFooter
  DocxHeaderFooter? loadFooter(String footerPath, int index, {int pageNumber = 1}) {
    final footerFile = archive.findFile(footerPath);
    if (footerFile == null) return null;
    
    try {
      final content = String.fromCharCodes(footerFile.content);
      final doc = XmlDocument.parse(content);
      return _parseHeaderFooterDoc(doc, index, pageNumber: pageNumber);
    } catch (e) {
      return null;
    }
  }

  /// Parse header/footer XML document into DocxHeaderFooter model
  DocxHeaderFooter _parseHeaderFooterDoc(XmlDocument doc, int index, {required int pageNumber}) {
    final paragraphs = <DocxParagraph>[];
    final images = <DocxImage>[];

    final pNodes = doc.findAllElements('w:p');
    for (var p in pNodes) {
      final runs = <DocxRun>[];
      
      // Parse field simple instructions like PAGE or NUMPAGES
      for (var fldSimple in p.findAllElements('w:fldSimple')) {
        final instr = fldSimple.getAttribute('w:instr') ?? '';
        if (instr.contains('PAGE')) {
          runs.add(DocxRun(
            text: '$pageNumber',
            isBold: true,
            fontSizePt: 10.0,
          ));
        }
      }

      // Process standard text runs
      for (var r in p.findAllElements('w:r')) {
        final t = r.findAllElements('w:t').map((e) => e.innerText).join();
        if (t.isNotEmpty) {
          final rPr = r.getElement('w:rPr');
          final isBold = rPr?.getElement('w:b') != null;
          final isItalic = rPr?.getElement('w:i') != null;

          runs.add(DocxRun(
            text: t,
            isBold: isBold,
            isItalic: isItalic,
            fontSizePt: 10.0,
          ));
        }
      }

      if (runs.isNotEmpty) {
        paragraphs.add(DocxParagraph(runs: runs));
      }
    }

    return DocxHeaderFooter(
      index: index,
      paragraphs: paragraphs,
      images: images,
    );
  }

  /// Build relationship map for headers/footers
  static Map<String, String> buildHeaderFooterRels(Archive archive, String headerFooterPath) {
    final rels = <String, String>{};
    final relsPath = headerFooterPath.replaceAll('.xml', '.xml.rels');
    final normalizedRelsPath = 'word/_rels/${relsPath.split('/').last}';
    
    final relsFile = archive.findFile(normalizedRelsPath);
    if (relsFile != null) {
      try {
        final doc = XmlDocument.parse(String.fromCharCodes(relsFile.content));
        for (var rel in doc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null) {
            final normalized = target.replaceAll('../', 'word/');
            rels[id] = normalized;
          }
        }
      } catch (e) {}
    }
    
    return rels;
  }
}

/// Header/Footer reference from section properties
class HeaderFooterReference {
  final String rId;
  final String path;
  final String type; // even, odd, first, default
  final bool isHeader;

  HeaderFooterReference({
    required this.rId,
    required this.path,
    required this.type,
    required this.isHeader,
  });

  /// Display name
  String get displayName {
    switch (type) {
      case 'even':
        return 'Even ${isHeader ? 'Header' : 'Footer'}';
      case 'odd':
        return 'Odd ${isHeader ? 'Header' : 'Footer'}';
      case 'first':
        return 'First ${isHeader ? 'Header' : 'Footer'}';
      default:
        return '${isHeader ? 'Header' : 'Footer'}';
    }
  }
}
