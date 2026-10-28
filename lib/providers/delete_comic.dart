// Remove a local download without removing its Jellyfin/Isar library entry.
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:kurage/models/entry.dart';
import 'package:kurage/variables.dart';
import 'package:path_provider/path_provider.dart';

/// Removes a downloaded volume without removing its Isar library entry.
/// Throws on filesystem failure and never touches the reader page cache.
Future<bool> removeDownloadedVolume(String id) async {
  final isar = Isar.getInstance();
  if (isar == null) throw StateError('Database unavailable');
  final entry = await isar.entrys.where().idEqualTo(id).findFirst();
  if (entry == null || !entry.downloaded) return false;

  final root = (await getApplicationDocumentsDirectory()).absolute.path;
  final directoryPath = entry.folderPath;
  if (directoryPath.isEmpty) {
    throw StateError('Download has no local directory');
  }
  final dir = Directory(directoryPath);
  final absolute = dir.absolute.path;
  // Never recursively delete the documents root (or a path outside it).
  if (absolute == root ||
      !absolute.startsWith('$root${Platform.pathSeparator}')) {
    throw StateError('Invalid download directory: $directoryPath');
  }

  // Old titles could map to the same extraction directory. Do not remove a
  // shared directory and silently corrupt another downloaded volume.
  final otherDownloads = await isar.entrys.where().filter()
      .downloadedEqualTo(true).findAll();
  if (otherDownloads.any((other) =>
      other.id != id && other.folderPath == directoryPath)) {
    throw StateError('Download directory is shared with another volume');
  }

  if (!await dir.exists()) {
    throw FileSystemException('Downloaded directory does not exist', directoryPath);
  }
  await dir.delete(recursive: true);

  // Preserve pageNum, progress, favorites, server metadata and image caches.
  entry
    ..downloaded = false
    ..folderPath = '';
  await isar.writeTxn(() async => isar.entrys.put(entry));
  logger.i('Removed local download: ${entry.title}');
  return true;
}

