// The purpose of this file is to define how book/comic entries are stored in the database

import 'package:isar_community/isar.dart';

part 'entry.g.dart';

enum EntryType {
  book,
  comic,
  folder,
  // Legacy Isar enum value: keep its index stable for existing installations.
  // Audio entries are filtered out by supported_formats.dart.
  audiobook,
}

@Collection()
class Entry {
  Id isarId = Isar.autoIncrement;

  @Index()
  String id;
  String title;
  String imagePath;
  bool downloaded = false;
  String path;
  String url;
  double progress = 0.0;
  int pageNum = 0;
  String folderPath = "";
  @enumerated
  EntryType type;
  String parentId = "";

  Entry({
    required this.id,
    required this.title,
    required this.imagePath,
    this.downloaded = false,
    required this.path,
    required this.url,
    this.progress = 0.0,
    this.pageNum = 0,
    this.folderPath = '',
    this.type = EntryType.book,
    this.parentId = '',
    this.isarId = Isar.autoIncrement,
  });

  // toString
  @override
  String toString() {
    return 'Entry{\n\tid: $id,\n\ttitle: $title,\n\timagePath: $imagePath,\n\tdownloaded: $downloaded,\n\tpath: $path,\n\turl: $url,\n\tprogress: $progress,\n\tpageNum: $pageNum,\n\tfolderPath: $folderPath,\n\ttype: $type,\n\tparentId: $parentId,\n}';
  }
}
