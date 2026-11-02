import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase openConnection({
  String dbName = 'taskcheck.db',
  bool inMemory = false,
}) {
  return LazyDatabase(() async {
    if (inMemory) {
      return NativeDatabase.memory(
        setup: (db) {
          db.execute('PRAGMA foreign_keys = ON;');
        },
      );
    }
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, dbName));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON;');
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA synchronous = NORMAL;');
      },
    );
  });
}
