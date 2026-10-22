import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorpdf/services/file_management_service.dart';

void main() {
  group('FileManagementService uri handling', () {
    test('prefers content uri identifiers over local paths', () {
      final picked = PlatformFile(
        name: 'sample.docx',
        size: 10,
        path: 'C:/temp/sample.docx',
        identifier: 'content://com.android.externalstorage.documents/document/primary%3ADownload%2Fsample.docx',
      );

      final normalized = FileManagementService.resolveDocumentSource(picked);

      expect(normalized, contains('content://'));
      expect(normalized, equals(picked.identifier));
    });

    test('detects content uri values', () {
      expect(FileManagementService.isContentUri('content://com.example/file.docx'), isTrue);
      expect(FileManagementService.isContentUri('/storage/emulated/0/Download/file.docx'), isFalse);
    });
  });
}
