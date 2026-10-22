import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/document.dart';
import 'document_picker_service.dart';

class FileManagementService {
  static const MethodChannel _channel = MethodChannel('com.tutorpdf/saf_reader');
  static const List<String> _allowedExtensions = [
    // Documents
    'pdf', 'doc', 'docx', 'rtf', 'odt', 'xps', 'oxps',
    // Presentations
    'ppt', 'pptx', 'odp',
    // Spreadsheets
    'xls', 'xlsx', 'ods', 'csv', 'tsv',
    // Plain Text & Code
    'txt', 'md', 'xml', 'json', 'yaml', 'yml', 'tex', 'log', 'ini', 'cfg',
    // eBooks
    'epub', 'mobi', 'azw', 'azw3', 'fb2',
    // Scanned Documents
    'djvu',
  ];

  Future<Document?> pickAndImportDocument() async {
    // Yield so the UI can show tap feedback before the native picker opens.
    await Future<void>.delayed(Duration.zero);

    debugPrint('Opening file picker...');
    await _requestStoragePermission();

    FilePickerResult? result;
    try {
      // FileType.any is more reliable on Android than custom MIME filters.
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
        allowCompression: false,
      );
    } on PlatformException catch (e) {
      debugPrint('FilePicker platform error: ${e.code} — ${e.message}');
      final message = switch (e.code) {
        'read_external_storage_denied' =>
          'Storage permission denied. Allow storage access in Settings.',
        'already_active' => 'File picker is already open.',
        'no_activity' => 'App is not in the foreground.',
        _ => e.message ?? e.code,
      };
      throw Exception(message);
    }

    if (result == null || result.files.isEmpty) {
      debugPrint('File picker cancelled or returned no files.');
      return null;
    }

    final picked = result.files.first;
    debugPrint(
      'Picked "${picked.name}" — path: ${picked.path ?? "(null, using content URI)"}',
    );

    final pickerService = DocumentPickerService();
    final docCandidate = await pickerService.processPickedFile(picked);

    if (!_allowedExtensions.contains(docCandidate.fileExtension)) {
      throw Exception(
        'Unsupported file type .${docCandidate.fileExtension}. '
        'Allowed: ${_allowedExtensions.join(', ')}',
      );
    }

    if (Platform.isAndroid && docCandidate.uriString.startsWith('content://')) {
      await persistUriPermission(docCandidate.uriString);
    }

    final id = await _insert(docCandidate);
    debugPrint('Imported document source: ${docCandidate.uriString} (id: $id)');
    return docCandidate.copyWith(id: id.toString());
  }

  Future<void> _requestStoragePermission() async {
    if (!Platform.isAndroid) return;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      final mediaStatus = await Permission.photos.request();
      if (mediaStatus.isGranted) return;
      final docsStatus = await Permission.videos.request();
      if (docsStatus.isGranted) return;
      throw Exception('Storage permission is required to open files from device storage.');
    }

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return;

    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted) return;

    throw Exception('Storage permission is required to open files from device storage.');
  }

  Future<void> ensureDocumentReadable(String filePath) async {
    if (Platform.isAndroid) {
      await _requestStoragePermission();
    }

    if (isContentUri(filePath)) {
      final exists = await _channel.invokeMethod<bool>('isValidSafUri', {'uri': filePath});
      if (exists != true) {
        throw Exception('The selected file could not be found.');
      }
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('The selected file could not be found.');
    }
  }

  static String? resolveDocumentSource(PlatformFile picked) {
    if (picked.identifier != null && picked.identifier!.isNotEmpty) {
      return picked.identifier;
    }

    final contentUriCandidates = <String?>[
      picked.path,
      picked.xFile.path,
    ];

    for (final candidate in contentUriCandidates) {
      if (candidate == null || candidate.isEmpty) continue;
      if (isContentUri(candidate)) {
        return candidate;
      }
    }

    for (final candidate in contentUriCandidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final source = File(candidate);
      if (source.existsSync()) {
        return source.absolute.path;
      }
    }

    return null;
  }

  static bool isContentUri(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    return value.startsWith('content://');
  }

  static Future<void> persistUriPermission(String value) async {
    if (!isContentUri(value)) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('takePersistableUriPermission', {'uri': value});
    } on MissingPluginException {
      debugPrint('Persistable URI permission channel unavailable.');
    }
  }

  Future<int> _insert(Document doc) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(
      'documents',
      doc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Document>> fetchAllOrderedByLastOpened() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('documents', orderBy: 'last_opened DESC');
    return rows.map(Document.fromMap).toList();
  }

  Future<List<Document>> fetchFavorites() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('documents',
        where: 'is_favorite = 1', orderBy: 'last_opened DESC');
    return rows.map(Document.fromMap).toList();
  }

  Future<Document?> fetchById(dynamic id) async {
    final parsedId = id is int ? id : int.tryParse(id.toString());
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [parsedId ?? id.toString()],
    );
    if (rows.isEmpty) return null;
    return Document.fromMap(rows.first);
  }

  Future<void> updateCurrentPage(dynamic documentId, int page) async {
    final parsedId = documentId is int ? documentId : int.tryParse(documentId.toString());
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'documents',
      {
        'current_page': page,
        'last_opened': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [parsedId ?? documentId.toString()],
    );
  }

  Future<void> updateTotalPages(dynamic documentId, int total) async {
    final parsedId = documentId is int ? documentId : int.tryParse(documentId.toString());
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'documents',
      {'total_pages': total},
      where: 'id = ?',
      whereArgs: [parsedId ?? documentId.toString()],
    );
  }

  Future<void> toggleFavorite(dynamic documentId, bool value) async {
    final parsedId = documentId is int ? documentId : int.tryParse(documentId.toString());
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'documents',
      {'is_favorite': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [parsedId ?? documentId.toString()],
    );
  }

  Future<void> deleteDocument(dynamic documentId) async {
    final parsedId = documentId is int ? documentId : int.tryParse(documentId.toString());
    final doc = await fetchById(documentId);
    final db = await DatabaseHelper.instance.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [parsedId ?? documentId.toString()]);
    if (parsedId != null) {
      await DatabaseHelper.instance.deleteFTSForDocument(parsedId);
    }
    if (doc != null && !doc.filePath.startsWith('content://')) {
      final file = File(doc.filePath);
      if (await file.exists()) await file.delete();
    }
  }
}
