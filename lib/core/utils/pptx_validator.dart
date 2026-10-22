import 'dart:io';
import 'package:flutter/foundation.dart';

/// PPTX File Integrity Validator
/// 
/// Performs pre-flight binary validation before attempting to render PPTX files.
/// Verifies ZIP magic bytes (PK..) and minimum file size to prevent crashes on corrupt files.
class PptxValidator {
  /// Minimum valid PPTX file size (1 KB)
  static const int minPptxSize = 1000;
  
  /// ZIP magic bytes: PK.. (0x50, 0x4B, 0x03, 0x04)
  static const List<int> zipMagicBytes = [0x50, 0x4B, 0x03, 0x04];

  /// Validates PPTX file header and size before rendering
  /// 
  /// Returns null if valid, or a descriptive user-friendly error message if validation fails.
  static Future<String?> validatePptxHeaderWithDetails(String path) async {
    try {
      final file = File(path);
      
      // 1. Check file existence
      if (!await file.exists()) {
        return 'Presentation file not found at: $path';
      }
      
      // 2. Check file size
      final length = await file.length();
      if (length < minPptxSize) {
        return 'Invalid presentation: file is incomplete or too small ($length bytes, minimum $minPptxSize required).';
      }
      
      // 3. Verify ZIP magic bytes (PK.. header)
      final bytes = await file.openRead(0, 4).first;
      if (bytes.length < 4) {
        return 'Unable to read presentation binary header.';
      }
      
      final isValidMagic = bytes[0] == zipMagicBytes[0] &&
                           bytes[1] == zipMagicBytes[1] &&
                           bytes[2] == zipMagicBytes[2] &&
                           bytes[3] == zipMagicBytes[3];
      
      if (!isValidMagic) {
        return 'Invalid PPTX presentation format: Missing standard ZIP header (PK..).';
      }
      
      debugPrint('[PptxValidator] Valid PPTX archive verified: $length bytes');
      return null;
    } catch (e) {
      return 'Failed to validate presentation binary header: $e';
    }
  }

  /// Deletes a corrupted cached file
  static Future<void> deleteCorruptFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[PptxValidator] Deleted corrupt file: $path');
      }
    } catch (e) {
      debugPrint('[PptxValidator] Error deleting corrupt file: $e');
    }
  }
}
