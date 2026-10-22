import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/document.dart';

class DocumentPickerService {
  static const MethodChannel _channel = MethodChannel('com.tutorpdf/saf_reader');

  /// Query Android ContentResolver via Method Channel for external content:// URIs
  static Future<String?> getMimeType(String uriString) async {
    if (!Platform.isAndroid || !uriString.startsWith('content://')) {
      return null;
    }
    try {
      final String? mimeType = await _channel.invokeMethod<String>('getMimeType', {'uri': uriString});
      return mimeType;
    } catch (e) {
      debugPrint('Error resolving MIME type from ContentResolver: $e');
      return null;
    }
  }

  /// Maps explicit MIME types to canonical extensions
  static String? extensionFromMimeType(String mimeType) {
    final lower = mimeType.toLowerCase().trim();
    if (lower == 'application/pdf') {
      return 'pdf';
    }
    if (lower == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
        lower == 'application/msword') {
      return 'docx';
    }
    if (lower == 'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
        lower == 'application/vnd.ms-powerpoint') {
      return 'pptx';
    }
    if (lower == 'text/plain') {
      return 'txt';
    }
    return null;
  }

  /// Processes picked PlatformFile cleanly without parsing URI strings to guess extensions
  Future<Document> processPickedFile(PlatformFile picked) async {
    final uriString = resolveUriString(picked);
    if (uriString == null || uriString.isEmpty) {
      throw Exception('Unable to resolve storage URI for selected file.');
    }

    final displayName = picked.name;

    // 1. Direct extension from PlatformFile object
    String fileExtension = picked.extension ?? '';
    if (fileExtension.isEmpty && displayName.contains('.')) {
      fileExtension = displayName.split('.').last;
    }
    fileExtension = fileExtension.replaceAll('.', '').toLowerCase();

    // 2. Query ContentResolver for content:// URIs to resolve accurate MIME type & extension
    String mimeType = '';
    if (uriString.startsWith('content://')) {
      final resolvedMime = await getMimeType(uriString);
      if (resolvedMime != null && resolvedMime.isNotEmpty) {
        mimeType = resolvedMime;
        final mappedExt = extensionFromMimeType(resolvedMime);
        if (mappedExt != null && mappedExt.isNotEmpty) {
          fileExtension = mappedExt;
        }
      }
    }

    if (fileExtension.isEmpty) {
      fileExtension = 'bin';
    }

    final now = DateTime.now().toIso8601String();
    return Document(
      id: '',
      displayName: displayName,
      fileExtension: fileExtension,
      mimeType: mimeType,
      uriString: uriString,
      totalPages: 0,
      currentPage: 0,
      isFavorite: false,
      lastOpened: now,
    );
  }

  static String? resolveUriString(PlatformFile picked) {
    if (picked.identifier != null && picked.identifier!.isNotEmpty) {
      return picked.identifier;
    }
    if (picked.path != null && picked.path!.isNotEmpty) {
      return picked.path;
    }
    if (picked.xFile.path.isNotEmpty) {
      return picked.xFile.path;
    }
    return null;
  }
}
