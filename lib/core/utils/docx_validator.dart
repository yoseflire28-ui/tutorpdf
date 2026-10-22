import 'dart:io';
import 'package:flutter/foundation.dart';

/// DOCX File Integrity Validator
/// 
/// Performs strict binary validation before attempting to render DOCX files.
/// Prevents rendering of corrupt files, HTTP error responses, or incomplete downloads.
class DocxValidator {
  /// Minimum valid DOCX file size (1 KB)
  static const int minDocxSize = 1000;
  
  /// ZIP magic bytes: PK.. (0x50, 0x4B, 0x03, 0x04)
  static const List<int> zipMagicBytes = [0x50, 0x4B, 0x03, 0x04];

  /// Validates DOCX file header and size before rendering
  /// 
  /// Returns true if:
  /// - File exists
  /// - File is at least 1 KB in size
  /// - File starts with ZIP magic bytes (PK..)
  /// 
  /// Returns false for corrupt, empty, or non-DOCX files.
  static Future<bool> validateDocxHeader(String path) async {
    try {
      final file = File(path);
      
      // Check file existence
      if (!await file.exists()) {
        debugPrint('[DocxValidator] File does not exist: $path');
        return false;
      }
      
      // Check file size
      final length = await file.length();
      if (length < minDocxSize) {
        debugPrint('[DocxValidator] File too small ($length bytes, minimum $minDocxSize): $path');
        return false;
      }
      
      // Verify ZIP magic bytes (PK.. header)
      final bytes = await file.openRead(0, 4).first;
      if (bytes.length < 4) {
        debugPrint('[DocxValidator] Could not read first 4 bytes: $path');
        return false;
      }
      
      final isValidMagic = bytes[0] == zipMagicBytes[0] &&
                           bytes[1] == zipMagicBytes[1] &&
                           bytes[2] == zipMagicBytes[2] &&
                           bytes[3] == zipMagicBytes[3];
      
      if (!isValidMagic) {
        debugPrint('[DocxValidator] Invalid ZIP magic bytes (expected ${zipMagicBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}, got ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}): $path');
        return false;
      }
      
      debugPrint('[DocxValidator] Valid DOCX archive. File Size: $length bytes');
      return true;
      
    } catch (e) {
      debugPrint('[DocxValidator] Validation error: $e');
      return false;
    }
  }

  /// Validates DOCX file and returns detailed error message if invalid
  /// 
  /// Returns null if valid, or error message string if invalid.
  static Future<String?> validateDocxHeaderWithDetails(String path) async {
    try {
      final file = File(path);
      
      if (!await file.exists()) {
        return 'File not found: $path';
      }
      
      final length = await file.length();
      if (length < minDocxSize) {
        return 'File Transfer Incomplete: The downloaded file is only $length bytes (minimum $minDocxSize bytes required). The file may be corrupt or missing binary data.';
      }
      
      final bytes = await file.openRead(0, 4).first;
      if (bytes.length < 4) {
        return 'Could not read file header. The file may be corrupt.';
      }
      
      final isValidMagic = bytes[0] == zipMagicBytes[0] &&
                           bytes[1] == zipMagicBytes[1] &&
                           bytes[2] == zipMagicBytes[2] &&
                           bytes[3] == zipMagicBytes[3];
      
      if (!isValidMagic) {
        return 'Invalid DOCX format: file is missing standard ZIP header (PK..). Bytes length: $length. This may be an HTTP error response or corrupt download.';
      }
      
      return null; // Valid
      
    } catch (e) {
      return 'Validation error: $e';
    }
  }

  /// Deletes a corrupt file from local storage
  static Future<void> deleteCorruptFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[DocxValidator] Deleted corrupt file: $path');
      }
    } catch (e) {
      debugPrint('[DocxValidator] Error deleting corrupt file: $e');
    }
  }
}
