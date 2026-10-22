import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// Universal File Path Resolver
/// 
/// Resolves Android Content Provider URIs (content://) to local temporary files
/// that can be accessed by Dart's standard File API.
/// 
/// This is necessary because Dart's File() constructor only works with POSIX paths,
/// not Android content:// URIs returned by file pickers and intent handlers.
class FilePathResolver {
  static const MethodChannel _channel = MethodChannel('com.tutorpdf/saf_reader');
  static final Map<String, String> _resolvedCache = {};

  /// Resolves a content:// URI or file path to a local temporary file path
  /// 
  /// For content:// URIs:
  /// - Reads the binary stream from Android Content Provider
  /// - Writes it to a temporary file in getTemporaryDirectory()
  /// - Returns the physical path to the temporary file
  /// 
  /// For regular file paths:
  /// - Returns the path directly if it exists
  /// 
  /// Throws an exception if resolution fails.
  static Future<String> resolveToLocalFilePath(String inputPath) async {
    if (inputPath.isEmpty) {
      throw Exception('File path is empty');
    }

    // Check cache first
    if (_resolvedCache.containsKey(inputPath)) {
      final cachedPath = _resolvedCache[inputPath]!;
      if (await File(cachedPath).exists()) {
        debugPrint('[FilePathResolver] Using cached resolved path: $cachedPath');
        return cachedPath;
      } else {
        _resolvedCache.remove(inputPath);
      }
    }

    // Handle content:// URIs
    if (inputPath.startsWith('content://')) {
      return await _resolveContentUri(inputPath);
    }

    // Handle file:// URIs
    if (inputPath.startsWith('file://')) {
      final filePath = inputPath.replaceFirst('file://', '');
      if (await File(filePath).exists()) {
        return filePath;
      }
      throw Exception('File not found: $filePath');
    }

    // Handle regular POSIX paths
    if (await File(inputPath).exists()) {
      return inputPath;
    }

    throw Exception('File not found: $inputPath');
  }

  /// Resolves a content:// URI to a local temporary file
  static Future<String> _resolveContentUri(String contentUri) async {
    try {
      debugPrint('[FilePathResolver] Resolving content URI: $contentUri');

      // Read bytes from Content Provider via MethodChannel
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
        'readSafFile',
        {'uri': contentUri},
      );

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to read content from URI: $contentUri');
      }

      debugPrint('[FilePathResolver] Read ${bytes.length} bytes from Content Provider');

      // Generate a unique filename based on URI hash
      final uriHash = sha256.convert(contentUri.codeUnits).toString().substring(0, 16);
      final tempDir = await getTemporaryDirectory();
      final extension = _guessExtensionFromUri(contentUri);
      final tempFileName = 'resolved_$uriHash.$extension';
      final tempFilePath = '${tempDir.path}/$tempFileName';

      // Write bytes to temporary file
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(bytes, flush: true);

      debugPrint('[FilePathResolver] Cached content URI to: $tempFilePath');

      // Cache the resolution
      _resolvedCache[contentUri] = tempFilePath;

      return tempFilePath;
    } catch (e) {
      debugPrint('[FilePathResolver] Error resolving content URI: $e');
      throw Exception('Failed to resolve content URI: $e');
    }
  }

  /// Guesses file extension from content URI or defaults to 'bin'
  static String _guessExtensionFromUri(String uri) {
    // Try to extract from URI path
    final uriParts = uri.split('/');
    final lastPart = uriParts.last;
    
    if (lastPart.contains('.')) {
      final ext = lastPart.split('.').last.toLowerCase();
      if (ext.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
        return ext;
      }
    }

    // Try to extract from display name if available
    if (uri.contains('%2E')) { // URL-encoded dot
      final decoded = Uri.decodeFull(uri);
      if (decoded.contains('.')) {
        final ext = decoded.split('.').last.toLowerCase();
        if (ext.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)) {
          return ext;
        }
      }
    }

    // Default to common document types based on URI patterns
    if (uri.contains('document') || uri.contains('word')) {
      return 'docx';
    }
    if (uri.contains('pdf')) {
      return 'pdf';
    }
    if (uri.contains('presentation') || uri.contains('powerpoint')) {
      return 'pptx';
    }

    return 'bin';
  }

  /// Clears the resolution cache and optionally deletes temporary files
  static Future<void> clearCache({bool deleteTempFiles = false}) async {
    if (deleteTempFiles) {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync().where((entity) =>
        entity.path.contains('resolved_') && entity is File
      ).cast<File>();

      for (final file in tempFiles) {
        try {
          await file.delete();
          debugPrint('[FilePathResolver] Deleted temp file: ${file.path}');
        } catch (e) {
          debugPrint('[FilePathResolver] Error deleting temp file: $e');
        }
      }
    }

    _resolvedCache.clear();
    debugPrint('[FilePathResolver] Cache cleared');
  }

  /// Gets the size of a resolved file without reading all bytes
  static Future<int> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Checks if a path is a content:// URI
  static bool isContentUri(String path) {
    return path.startsWith('content://');
  }

  /// Checks if a path is a file:// URI
  static bool isFileUri(String path) {
    return path.startsWith('file://');
  }
}
