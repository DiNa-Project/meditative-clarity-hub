import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/meditation_session.dart';

class MeditationSessionStore {
  static const _legacyPrefsKey = 'meditation_sessions';
  static const _migrationFlagKey = 'meditation_sessions_migrated_to_sqlite';
  static const _dbName = 'meditative_clarity_hub.db';
  static const _tableName = 'meditation_sessions';

  static Future<Database>? _dbFuture;

  static Future<Database> _db() {
    return _dbFuture ??= _openDb();
  }

  static Future<Database> _openDb() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _dbName);
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            device_id TEXT NOT NULL,
            user_name TEXT NOT NULL,
            start_date TEXT NOT NULL,
            music_start_time TEXT NOT NULL,
            answers_json TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    await _migrateLegacyPrefsIfNeeded(db);
    return db;
  }

  static Future<void> _migrateLegacyPrefsIfNeeded(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migrationFlagKey) ?? false;
    if (alreadyMigrated) {
      return;
    }

    final raw = prefs.getString(_legacyPrefsKey);
    if (raw == null || raw.isEmpty) {
      await prefs.setBool(_migrationFlagKey, true);
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final sessions = decoded
          .map(
            (item) => MeditationSession.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      await db.transaction((txn) async {
        for (final session in sessions) {
          await txn.insert(
            _tableName,
            _toDbMap(session),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

      await prefs.remove(_legacyPrefsKey);
      await prefs.setBool(_migrationFlagKey, true);
      print('MIGRATION_DEBUG migrated ${sessions.length} sessions to SQLite');
    } catch (e) {
      print('ERROR: Failed migrating legacy session store: $e');
    }
  }

  static Map<String, dynamic> _toDbMap(MeditationSession session) {
    return {
      'id': session.id,
      'device_id': session.deviceId,
      'user_name': session.userName,
      'start_date': session.startDate,
      'music_start_time': session.musicStartTime,
      'answers_json': jsonEncode(session.answers),
      'synced': session.synced ? 1 : 0,
    };
  }

  static MeditationSession _fromDbRow(Map<String, Object?> row) {
    final answersRaw = row['answers_json'] as String;
    final answers = (jsonDecode(answersRaw) as List<dynamic>)
        .map((value) => (value as num).toDouble())
        .toList();

    return MeditationSession(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      userName: row['user_name'] as String,
      startDate: row['start_date'] as String,
      musicStartTime: row['music_start_time'] as String,
      answers: answers,
      synced: (row['synced'] as int? ?? 0) == 1,
    );
  }

  static Future<List<MeditationSession>> loadAll() async {
    final db = await _db();
    final rows = await db.query(_tableName, orderBy: 'music_start_time ASC');
    return rows.map(_fromDbRow).toList();
  }

  static Future<void> saveAll(List<MeditationSession> sessions) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete(_tableName);
      for (final session in sessions) {
        await txn.insert(
          _tableName,
          _toDbMap(session),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> add(MeditationSession session) async {
    final db = await _db();
    await db.insert(
      _tableName,
      _toDbMap(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> markSynced(Set<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await _db();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $_tableName SET synced = 1 WHERE id IN ($placeholders)',
      ids.toList(),
    );
  }
}
