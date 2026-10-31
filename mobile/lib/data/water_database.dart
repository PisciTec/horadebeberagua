import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/water_record.dart';

/// Banco local SQLite (substitui o object store `water_history` do IndexedDB).
class WaterDatabase {
  static const _dbName = 'aquavoice.db';
  static const _table = 'water_history';

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            amount INTEGER NOT NULL,
            type TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_water_ts ON $_table(timestamp)');
      },
    );
    return _db!;
  }

  Future<int> insert(WaterRecord record) async {
    final db = await _database;
    return db.insert(_table, record.toMap());
  }

  /// Registros com timestamp em [start, end).
  Future<List<WaterRecord>> recordsBetween(DateTime start, DateTime end) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
    return rows.map(WaterRecord.fromMap).toList();
  }

  /// Todos os registros (usado no cálculo da sequência de dias).
  Future<List<WaterRecord>> allRecords() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'timestamp DESC');
    return rows.map(WaterRecord.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete(_table);
  }
}
