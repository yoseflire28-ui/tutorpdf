import 'package:flutter_test/flutter_test.dart';
import 'package:tutorpdf/data/providers/active_document_provider.dart';
import 'package:tutorpdf/models/document.dart';
import 'package:tutorpdf/utils/file_icon_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActiveDocumentProvider & Multi-Format AI Support Tests', () {
    test('ActiveDocumentProvider manages active document and converted PDF paths', () async {
      final provider = ActiveDocumentProvider();
      expect(provider.hasActiveDocument, isFalse);
      expect(provider.activeDocument, isNull);

      const doc = Document(
        id: 'doc_1',
        displayName: 'Test Presentation.pptx',
        fileExtension: 'pptx',
        uriString: '/path/to/test.pptx',
        lastOpened: '2026-08-31T00:00:00.000Z',
      );

      await provider.setActiveDocument(doc, convertedPdfPath: '/cache/converted_doc.pdf');
      expect(provider.hasActiveDocument, isTrue);
      expect(provider.activeDocument?.displayName, equals('Test Presentation.pptx'));
      expect(provider.convertedPdfPath, equals('/cache/converted_doc.pdf'));

      provider.clearActiveDocument();
      expect(provider.hasActiveDocument, isFalse);
      expect(provider.activeDocument, isNull);
    });

    test('FileIconHelper.isAiSupportedFile validates all required AI formats', () {
      expect(FileIconHelper.isAiSupportedFile('pdf'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('docx'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('doc'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('pptx'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('ppt'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('txt'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('md'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('csv'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('xlsx'), isTrue);
      expect(FileIconHelper.isAiSupportedFile('json'), isTrue);

      expect(FileIconHelper.isAiSupportedFile('exe'), isFalse);
      expect(FileIconHelper.isAiSupportedFile('mp3'), isFalse);
    });
  });
}
