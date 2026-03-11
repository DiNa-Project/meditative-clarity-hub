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
  static const _maxBackoffHours = 24;

  static Future<Database>? _dbFuture;

  static Future<Database> _db() {
    return _dbFuture ??= _openDb();
  }

  static Future<Database> _openDb() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _dbName);
    final db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            device_id TEXT NOT NULL,
            user_name TEXT NOT NULL,
            start_date TEXT NOT NULL,
            music_start_time TEXT NOT NULL,
            answers_json TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at TEXT,
            last_error TEXT
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0',
          );
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN next_retry_at TEXT',
          );
          await database.execute(
            'ALTER TABLE $_tableName ADD COLUMN last_error TEXT',
          );
        }
      },
    );

    await _ensureRequiredColumns(db);

    await _migrateLegacyPrefsIfNeeded(db);
    return db;
  }

  static Future<void> _ensureRequiredColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($_tableName)');
    final existing = columns
        .map((row) => (row['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!existing.contains('retry_count')) {
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!existing.contains('next_retry_at')) {
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN next_retry_at TEXT',
      );
    }
    if (!existing.contains('last_error')) {
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN last_error TEXT',
      );
    }
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
      'retry_count': 0,
      'next_retry_at': null,
      'last_error': null,
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

  static Future<List<MeditationSession>> loadPendingDue({DateTime? now}) async {
    final db = await _db();
    final nowIso = (now ?? DateTime.now()).toIso8601String();
    final rows = await db.query(
      _tableName,
      where: 'synced = 0 AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [nowIso],
      orderBy: 'music_start_time ASC',
    );
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

  static Future<void> clearAll() async {
    final db = await _db();
    await db.delete(_tableName);
  }

  static Future<void> markSynced(Set<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await _db();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $_tableName '
      'SET synced = 1, retry_count = 0, next_retry_at = NULL, last_error = NULL '
      'WHERE id IN ($placeholders)',
      ids.toList(),
    );
  }

  static Future<void> markSyncFailed(
    Set<String> ids, {
    required String error,
  }) async {
    if (ids.isEmpty) {
      return;
    }

    final db = await _db();
    await db.transaction((txn) async {
      for (final id in ids) {
        final rows = await txn.query(
          _tableName,
          columns: ['retry_count'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) {
          continue;
        }

        final currentRetry = (rows.first['retry_count'] as int? ?? 0) + 1;
        final backoffHours = _computeBackoffHours(currentRetry);
        final nextRetryAt = DateTime.now()
            .add(Duration(hours: backoffHours))
            .toIso8601String();

        await txn.update(
          _tableName,
          {
            'retry_count': currentRetry,
            'next_retry_at': nextRetryAt,
            'last_error': error,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  static int _computeBackoffHours(int retryCount) {
    final clamped = retryCount < 1 ? 1 : retryCount;
    final computed = 1 << (clamped - 1);
    if (computed > _maxBackoffHours) {
      return _maxBackoffHours;
    }
    return computed;
  }
}
