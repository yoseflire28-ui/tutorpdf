import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class BackupService {
  static const _dbName = 'tutorpdf.db';
  static const _docsFolder = 'user_documents';

  Future<void> exportBackup() async {
    await DatabaseHelper.instance.close();

    try {
      final dbPath = await _resolveDbPath();
      final docsDir = await _resolveDocsDir();
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, 'tutorpdf_backup.zip');

      final archive = Archive();

      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final bytes = await dbFile.readAsBytes();
        archive.addFile(ArchiveFile(_dbName, bytes.length, bytes));
      }

      if (await docsDir.exists()) {
        await for (final entity in docsDir.list(recursive: true)) {
          if (entity is File) {
            final relative = p.relative(entity.path, from: docsDir.parent.path);
            final bytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile(relative, bytes.length, bytes));
          }
        }
      }

      final encoded = ZipEncoder().encode(archive);
      if (encoded == null) throw Exception('Failed to encode zip archive.');
      await File(zipPath).writeAsBytes(encoded);

      await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        subject: 'TutorPDF Backup',
        text: 'TutorPDF backup created on ${DateTime.now().toIso8601String()}',
      );
    } finally {
      await DatabaseHelper.instance.database;
    }
  }

  Future<void> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final zipPath = result.files.first.path;
    if (zipPath == null) throw Exception('Could not resolve zip path.');

    await DatabaseHelper.instance.close();

    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final dbDestPath = await _resolveDbPath();
      final docsDir = await _resolveDocsDir();

      if (await docsDir.exists()) await docsDir.delete(recursive: true);
      await docsDir.create(recursive: true);

      for (final file in archive) {
        if (file.isFile) {
          final content = file.content as List<int>;

          if (file.name == _dbName) {
            await File(dbDestPath).writeAsBytes(content);
          } else if (file.name.startsWith(_docsFolder)) {
            final destPath = p.join(docsDir.parent.path, file.name);
            final destFile = File(destPath);
            await destFile.parent.create(recursive: true);
            await destFile.writeAsBytes(content);
          }
        }
      }
    } catch (e) {
      await DatabaseHelper.instance.database;
      rethrow;
    }

    await DatabaseHelper.instance.database;
  }

  Future<String> _resolveDbPath() async {
    final dir = await getDatabasesPath();
    return p.join(dir, _dbName);
  }

  Future<Directory> _resolveDocsDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, _docsFolder));
  }
}