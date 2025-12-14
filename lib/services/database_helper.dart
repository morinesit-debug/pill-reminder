import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform, Directory, File;
import '../models/pill.dart';
import '../models/pill_record.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static SharedPreferences? _prefs;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) return null;

    String path;
    if (Platform.isIOS) {
      // iOS에서는 Documents 디렉토리 사용 (쓰기 권한 보장)
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'pill_reminder.db');

      // 디렉토리가 존재하는지 확인하고 생성
      final dir = Directory(documentsDirectory.path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // iOS에서 데이터베이스 파일 권한을 더 확실하게 설정
      try {
        // 디렉토리 쓰기 권한 테스트
        final testFile = File('${documentsDirectory.path}/test_write.txt');
        await testFile.writeAsString('test');
        await testFile.delete();

        // 기존 데이터베이스 파일이 있으면 완전히 삭제
        final dbFile = File(path);
        if (await dbFile.exists()) {
          await dbFile.delete();

          // 삭제 후 잠시 대기 (파일 시스템 동기화)
          await Future.delayed(Duration(milliseconds: 100));
        }
      } catch (writeError) {
        // 권한 문제가 있으면 다른 경로 시도
        throw Exception('Documents 디렉토리에 쓰기 권한이 없습니다: $writeError');
      }
    } else {
      // Android에서는 기본 데이터베이스 경로 사용
      path = join(await getDatabasesPath(), 'pill_reminder.db');
    }

    try {
      // 새 데이터베이스 생성
      final database = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) {},
        readOnly: false, // 명시적으로 읽기/쓰기 모드로 설정
        singleInstance: true, // 단일 인스턴스로 설정하여 권한 충돌 방지
      );

      // 데이터베이스가 실제로 쓰기 가능한지 테스트
      try {
        await database.execute(
          'CREATE TABLE IF NOT EXISTS test_table (id INTEGER)',
        );
        await database.execute('DROP TABLE test_table');
      } catch (testError) {
        await database.close();
        throw Exception('데이터베이스가 쓰기 불가능합니다: $testError');
      }

      return database;
    } catch (e) {
      // iOS에서 권한 문제가 발생한 경우 추가 시도
      if (Platform.isIOS) {
        try {
          // 임시 경로 시도
          final tempDir = await getTemporaryDirectory();
          final tempPath = join(tempDir.path, 'pill_reminder_temp.db');

          final tempDatabase = await openDatabase(
            tempPath,
            version: 1,
            onCreate: _onCreate,
            readOnly: false,
          );

          return tempDatabase;
        } catch (tempError) {
          // 마지막 시도: 앱 번들 내부 경로
          try {
            final appSupportDir = await getApplicationSupportDirectory();
            final appSupportPath = join(appSupportDir.path, 'pill_reminder.db');

            final appSupportDatabase = await openDatabase(
              appSupportPath,
              version: 1,
              onCreate: _onCreate,
              readOnly: false,
            );

            return appSupportDatabase;
          } catch (appSupportError) {
            // 모든 시도 실패
          }
        }
      }

      return null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 알약 테이블
    await db.execute('''
      CREATE TABLE pills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL,
        startDate INTEGER NOT NULL,
        customDays INTEGER,
        isActive INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        alarmTimes TEXT NOT NULL
      )
    ''');

    // 알약 복용 기록 테이블
    await db.execute('''
      CREATE TABLE pill_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pillId INTEGER NOT NULL,
        scheduledDate INTEGER NOT NULL,
        takenDate INTEGER,
        isTaken INTEGER NOT NULL,
        isSkipped INTEGER NOT NULL,
        FOREIGN KEY (pillId) REFERENCES pills (id) ON DELETE CASCADE
      )
    ''');
  }

  // Web-specific data save/load methods
  Future<void> _saveToPrefs(String key, List<Map<String, dynamic>> data) async {
    final prefs = await this.prefs;
    final jsonString = jsonEncode(data);
    await prefs.setString(key, jsonString);
  }

  Future<List<Map<String, dynamic>>> _loadFromPrefs(String key) async {
    final prefs = await this.prefs;
    final jsonString = prefs.getString(key);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final result = jsonList.cast<Map<String, dynamic>>();
      return result;
    } catch (e) {
      return [];
    }
  }

  // 알약 CRUD 작업
  Future<int> insertPill(Pill pill) async {
    if (kIsWeb) {
      final pills = await _loadFromPrefs('pills');
      final newId = pills.isEmpty
          ? 1
          : (pills.map((p) => p['id'] as int).reduce((a, b) => a > b ? a : b) +
                1);
      final pillMap = pill.copyWith(id: newId).toMap();
      pills.add(pillMap);
      await _saveToPrefs('pills', pills);
      return newId;
    } else {
      final db = await database;
      if (db == null) {
        return 0;
      }
      final id = await db.insert('pills', pill.toMap());
      return id;
    }
  }

  Future<List<Pill>> getAllPills() async {
    if (kIsWeb) {
      final pills = await _loadFromPrefs('pills');
      final result = pills.map((p) => Pill.fromMap(p)).toList();
      return result;
    } else {
      final db = await database;
      if (db == null) {
        return [];
      }
      final List<Map<String, dynamic>> maps = await db.query('pills');
      final result = maps.map((map) => Pill.fromMap(map)).toList();
      return result;
    }
  }

  Future<Pill?> getPill(int id) async {
    if (kIsWeb) {
      final pills = await _loadFromPrefs('pills');
      final pillMap = pills.firstWhere((p) => p['id'] == id, orElse: () => {});
      if (pillMap.isNotEmpty) {
        return Pill.fromMap(pillMap);
      }
      return null;
    } else {
      final db = await database;
      if (db == null) return null;
      final List<Map<String, dynamic>> maps = await db.query(
        'pills',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Pill.fromMap(maps.first);
      }
      return null;
    }
  }

  Future<int> updatePill(Pill pill) async {
    if (kIsWeb) {
      final pills = await _loadFromPrefs('pills');
      final index = pills.indexWhere((p) => p['id'] == pill.id);
      if (index != -1) {
        pills[index] = pill.toMap();
        await _saveToPrefs('pills', pills);
        return 1;
      }
      return 0;
    } else {
      final db = await database;
      if (db == null) return 0;
      return await db.update(
        'pills',
        pill.toMap(),
        where: 'id = ?',
        whereArgs: [pill.id],
      );
    }
  }

  Future<int> deletePill(int id) async {
    if (kIsWeb) {
      final pills = await _loadFromPrefs('pills');
      pills.removeWhere((p) => p['id'] == id);
      await _saveToPrefs('pills', pills);

      // 관련 복용 기록도 삭제
      final records = await _loadFromPrefs('pill_records');
      records.removeWhere((r) => r['pillId'] == id);
      await _saveToPrefs('pill_records', records);

      return 1;
    } else {
      final db = await database;
      if (db == null) return 0;
      return await db.delete('pills', where: 'id = ?', whereArgs: [id]);
    }
  }

  // 알약 복용 기록 CRUD 작업
  Future<int> insertPillRecord(PillRecord record) async {
    if (kIsWeb) {
      final records = await _loadFromPrefs('pill_records');
      final newId = records.isEmpty
          ? 1
          : (records
                    .map((r) => r['id'] as int)
                    .reduce((a, b) => a > b ? a : b) +
                1);

      final recordMap = record.copyWith(id: newId).toMap();

      records.add(recordMap);
      await _saveToPrefs('pill_records', records);

      return newId;
    } else {
      final db = await database;
      if (db == null) {
        return 0;
      }

      final id = await db.insert('pill_records', record.toMap());
      return id;
    }
  }

  Future<List<PillRecord>> getPillRecords(int pillId) async {
    if (kIsWeb) {
      final records = await _loadFromPrefs('pill_records');
      return records
          .where((r) => r['pillId'] == pillId)
          .map((map) => PillRecord.fromMap(map))
          .toList();
    } else {
      final db = await database;
      if (db == null) return [];
      final List<Map<String, dynamic>> maps = await db.query(
        'pill_records',
        where: 'pillId = ?',
        whereArgs: [pillId],
        orderBy: 'scheduledDate DESC',
      );
      return List.generate(maps.length, (i) => PillRecord.fromMap(maps[i]));
    }
  }

  Future<List<PillRecord>> getPillRecordsByDate(DateTime date) async {
    if (kIsWeb) {
      final records = await _loadFromPrefs('pill_records');
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      return records
          .where((r) {
            final scheduledDate = DateTime.fromMillisecondsSinceEpoch(
              r['scheduledDate'],
            );
            return scheduledDate.isAfter(startOfDay) &&
                scheduledDate.isBefore(endOfDay);
          })
          .map((map) => PillRecord.fromMap(map))
          .toList();
    } else {
      final db = await database;
      if (db == null) return [];
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final List<Map<String, dynamic>> maps = await db.query(
        'pill_records',
        where: 'scheduledDate >= ? AND scheduledDate < ?',
        whereArgs: [
          startOfDay.millisecondsSinceEpoch,
          endOfDay.millisecondsSinceEpoch,
        ],
      );
      return List.generate(maps.length, (i) => PillRecord.fromMap(maps[i]));
    }
  }

  Future<int> updatePillRecord(PillRecord record) async {
    if (kIsWeb) {
      final records = await _loadFromPrefs('pill_records');
      final index = records.indexWhere((r) => r['id'] == record.id);
      if (index != -1) {
        records[index] = record.toMap();
        await _saveToPrefs('pill_records', records);
        return 1;
      }
      return 0;
    } else {
      final db = await database;
      if (db == null) return 0;
      return await db.update(
        'pill_records',
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
    }
  }

  Future<int> deletePillRecord(int id) async {
    if (kIsWeb) {
      final records = await _loadFromPrefs('pill_records');
      records.removeWhere((r) => r['id'] == id);
      await _saveToPrefs('pill_records', records);
      return 1;
    } else {
      final db = await database;
      if (db == null) return 0;
      return await db.delete('pill_records', where: 'id = ?', whereArgs: [id]);
    }
  }

  // 특정 날짜의 알약 복용 상태 조회
  Future<Map<int, PillRecord?>> getPillStatusForDate(DateTime date) async {
    if (kIsWeb) {
      final records = await _loadFromPrefs('pill_records');

      final dateOnly = DateTime(date.year, date.month, date.day);
      final filteredRecords = records.where((record) {
        final recordDate = DateTime.fromMillisecondsSinceEpoch(
          record['scheduledDate'],
        );
        final recordDateOnly = DateTime(
          recordDate.year,
          recordDate.month,
          recordDate.day,
        );
        final isSameDate = recordDateOnly.isAtSameMomentAs(dateOnly);
        return isSameDate;
      }).toList();

      final result = <int, PillRecord?>{};
      for (final record in filteredRecords) {
        final pillRecord = PillRecord.fromMap(record);
        result[pillRecord.pillId] = pillRecord;
      }

      return result;
    } else {
      final db = await database;
      if (db == null) {
        return {};
      }

      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOfDay = dateOnly.millisecondsSinceEpoch;
      final endOfDay =
          dateOnly.add(const Duration(days: 1)).millisecondsSinceEpoch - 1;

      final List<Map<String, dynamic>> records = await db.query(
        'pill_records',
        where: 'scheduledDate >= ? AND scheduledDate <= ?',
        whereArgs: [startOfDay, endOfDay],
      );

      final result = <int, PillRecord?>{};
      for (final record in records) {
        final pillRecord = PillRecord.fromMap(record);
        result[pillRecord.pillId] = pillRecord;
      }

      return result;
    }
  }
}
