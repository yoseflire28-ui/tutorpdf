import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../models/document.dart';

enum ViewMode { grid, list }
enum SortOption { date, name, size }

class FileService {
  static ViewMode _currentViewMode = ViewMode.grid;
  static SortOption _currentSortOption = SortOption.date;
  static bool _isFullScreen = false;

  static ViewMode get currentViewMode => _currentViewMode;
  static SortOption get currentSortOption => _currentSortOption;
  static bool get isFullScreen => _isFullScreen;

  static void setViewMode(ViewMode mode) {
    _currentViewMode = mode;
  }

  static void toggleViewMode() {
    _currentViewMode = _currentViewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid;
  }

  static void setSortOption(SortOption option) {
    _currentSortOption = option;
  }

  static Future<Directory> getApplicationDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      throw Exception('Failed to get application directory: $e');
    }
  }

  static Future<Directory> getPdfDirectory() async {
    try {
      final appDir = await getApplicationDirectory();
      final pdfDir = Directory(p.join(appDir.path, 'pdfs'));
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }
      return pdfDir;
    } catch (e) {
      throw Exception('Failed to get PDF directory: $e');
    }
  }

  static Future<List<Document>> searchFiles(String query, List<Document> documents) async {
    try {
      if (query.isEmpty) {
        return documents;
      }

      final lowerQuery = query.toLowerCase();
      return documents.where((doc) {
        final fileName = doc.fileName.toLowerCase();
        final fileType = doc.fileType.toLowerCase();
        return fileName.contains(lowerQuery) || fileType.contains(lowerQuery);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search files: $e');
    }
  }

  static Future<List<Document>> sortFiles(List<Document> documents, SortOption option) async {
    try {
      final sortedDocs = List<Document>.from(documents);
      
      switch (option) {
        case SortOption.date:
          sortedDocs.sort((a, b) {
            final dateA = DateTime.tryParse(a.lastOpened) ?? DateTime(0);
            final dateB = DateTime.tryParse(b.lastOpened) ?? DateTime(0);
            return dateB.compareTo(dateA);
          });
          break;
        case SortOption.name:
          sortedDocs.sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
          break;
        case SortOption.size:
          try {
            for (final doc in sortedDocs) {
              final file = File(doc.filePath);
              if (await file.exists()) {
                final size = await file.length();
              }
            }
          } catch (e) {
            // If size retrieval fails, keep original order
          }
          sortedDocs.sort((a, b) => a.fileName.compareTo(b.fileName));
          break;
      }
      
      return sortedDocs;
    } catch (e) {
      throw Exception('Failed to sort files: $e');
    }
  }

  static Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      throw Exception('Failed to copy to clipboard: $e');
    }
  }

  static Future<void> shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }
      await Share.shareXFiles([XFile(filePath)], subject: 'Share PDF');
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  static Future<void> copyFile(String sourcePath, String targetDirectory) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist: $sourcePath');
      }

      final targetDir = Directory(targetDirectory);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final fileName = p.basename(sourcePath);
      final targetPath = p.join(targetDirectory, fileName);
      
      // Handle duplicate filenames
      var finalTargetPath = targetPath;
      int counter = 1;
      while (await File(finalTargetPath).exists()) {
        final nameWithoutExt = p.basenameWithoutExtension(sourcePath);
        final ext = p.extension(sourcePath);
        finalTargetPath = p.join(targetDirectory, '${nameWithoutExt}_$counter$ext');
        counter++;
      }

      await sourceFile.copy(finalTargetPath);
    } catch (e) {
      throw Exception('Failed to copy file: $e');
    }
  }

  static Future<void> moveFile(String sourcePath, String targetDirectory) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist: $sourcePath');
      }

      final targetDir = Directory(targetDirectory);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final fileName = p.basename(sourcePath);
      final targetPath = p.join(targetDirectory, fileName);
      
      // Handle duplicate filenames
      var finalTargetPath = targetPath;
      int counter = 1;
      while (await File(finalTargetPath).exists()) {
        final nameWithoutExt = p.basenameWithoutExtension(sourcePath);
        final ext = p.extension(sourcePath);
        finalTargetPath = p.join(targetDirectory, '${nameWithoutExt}_$counter$ext');
        counter++;
      }

      await sourceFile.rename(finalTargetPath);
    } catch (e) {
      throw Exception('Failed to move file: $e');
    }
  }

  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  static Future<String> renameFile(String oldPath, String newName) async {
    try {
      final oldFile = File(oldPath);
      if (!await oldFile.exists()) {
        throw Exception('File does not exist: $oldPath');
      }

      final directory = p.dirname(oldPath);
      final newPath = p.join(directory, newName);
      
      if (await File(newPath).exists()) {
        throw Exception('A file with this name already exists');
      }

      await oldFile.rename(newPath);
      return newPath;
    } catch (e) {
      throw Exception('Failed to rename file: $e');
    }
  }

  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<DateTime> getFileModifiedDate(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.lastModified();
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  static Future<void> toggleFullScreen() async {
    try {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      _isFullScreen = false;
      throw Exception('Failed to toggle full screen: $e');
    }
  }

  static Future<void> exitFullScreen() async {
    try {
      if (_isFullScreen) {
        _isFullScreen = false;
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      throw Exception('Failed to exit full screen: $e');
    }
  }

  static String getFileName(String filePath) {
    try {
      return p.basename(filePath);
    } catch (e) {
      return filePath;
    }
  }

  static Future<String> getFileExtension(String filePath) async {
    try {
      return p.extension(filePath).replaceAll('.', '').toLowerCase();
    } catch (e) {
      return '';
    }
  }

  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> getAllPdfFiles() async {
    try {
      final pdfDir = await getPdfDirectory();
      final entities = pdfDir.listSync();
      final pdfFiles = <String>[];
      
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          pdfFiles.add(entity.path);
        }
      }
      
      return pdfFiles;
    } catch (e) {
      throw Exception('Failed to get PDF files: $e');
    }
  }

  static Future<List<String>> getAllFilesInDirectory(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        return [];
      }
      
      final entities = dir.listSync();
      final files = <String>[];
      
      for (final entity in entities) {
        if (entity is File) {
          files.add(entity.path);
        }
      }
      
      return files;
    } catch (e) {
      throw Exception('Failed to get files in directory: $e');
    }
  }

  static Future<void> createDirectory(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to create directory: $e');
    }
  }

  static Future<void> deleteDirectory(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to delete directory: $e');
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }
}
