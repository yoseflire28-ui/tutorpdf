import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils/file_path_resolver.dart';

/// Zero-Copy Stream Handler
/// Reads byte streams directly from content:// URIs using native ContentResolver
/// or File(uri).openRead() without copying files into /data/user/0/.../cache/
class ContentStreamReader {
  static const MethodChannel _channel = MethodChannel('com.tutorpdf/saf_reader');

  /// Reads bytes zero-copy directly from content:// URI or local filesystem path
  /// 
  /// This method now automatically resolves content:// URIs to local temporary files
  /// before reading, ensuring compatibility with Dart's File API.
  static Future<Uint8List> readBytes(String uriString) async {
    // Resolve content:// URIs to local file paths first
    String resolvedPath = uriString;
    if (FilePathResolver.isContentUri(uriString) || FilePathResolver.isFileUri(uriString)) {
      try {
        debugPrint('[ContentStreamReader] Resolving URI before reading: $uriString');
        resolvedPath = await FilePathResolver.resolveToLocalFilePath(uriString);
        debugPrint('[ContentStreamReader] Resolved to: $resolvedPath');
      } catch (e) {
        debugPrint('[ContentStreamReader] URI resolution failed, falling back to direct read: $e');
        // Fallback to direct MethodChannel read if resolution fails
        if (uriString.startsWith('content://')) {
          final Uint8List? bytes = await _channel.invokeMethod<Uint8List>(
            'readSafFile',
            {'uri': uriString},
          );
          if (bytes != null && bytes.isNotEmpty) {
            return bytes;
          }
        }
        throw Exception('Failed to resolve and read content URI: $e');
      }
    }

    // Read from resolved local file path
    final file = File(resolvedPath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }

    throw Exception('Failed to read document bytes from: $resolvedPath');
  }

  /// Opens a zero-copy byte stream
  static Stream<List<int>> openRead(String uriString) {
    if (uriString.startsWith('content://')) {
      return Stream.fromFuture(readBytes(uriString));
    }
    return File(uriString).openRead();
  }
}
