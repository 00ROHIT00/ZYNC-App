import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class ScanLogDb {
  static final ScanLogDb _instance = ScanLogDb._internal();
  factory ScanLogDb() => _instance;
  ScanLogDb._internal();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'scan_logs.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ssid TEXT NOT NULL,
            bssid TEXT NOT NULL,
            security TEXT NOT NULL,
            channel INTEGER,
            rssi INTEGER,
            firstSeenAt INTEGER NOT NULL,
            lastSeenAt INTEGER NOT NULL,
            seenCount INTEGER NOT NULL DEFAULT 1,
            risk TEXT NOT NULL,
            source TEXT,
            sessionId TEXT
          );
        ''');
        await db.execute('CREATE INDEX idx_scan_bssid ON scan_entries(bssid);');
        await db.execute('CREATE INDEX idx_scan_ssid ON scan_entries(ssid);');
        await db.execute(
            'CREATE INDEX idx_scan_lastSeen ON scan_entries(lastSeenAt);');
        await db.execute(
            'CREATE INDEX idx_scan_sessionId ON scan_entries(sessionId);');
        
        // Create scan sessions table
        await db.execute('''
          CREATE TABLE scan_sessions (
            id TEXT PRIMARY KEY,
            timestamp INTEGER NOT NULL,
            totalNetworks INTEGER NOT NULL,
            secureNetworks INTEGER NOT NULL,
            vulnerableNetworks INTEGER NOT NULL
          );
        ''');
        await db.execute(
            'CREATE INDEX idx_session_timestamp ON scan_sessions(timestamp);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add sessionId column to existing table
          await db.execute('ALTER TABLE scan_entries ADD COLUMN sessionId TEXT;');
          await db.execute(
              'CREATE INDEX idx_scan_sessionId ON scan_entries(sessionId);');
          
          // Create scan sessions table
          await db.execute('''
            CREATE TABLE scan_sessions (
              id TEXT PRIMARY KEY,
              timestamp INTEGER NOT NULL,
              totalNetworks INTEGER NOT NULL,
              secureNetworks INTEGER NOT NULL,
              vulnerableNetworks INTEGER NOT NULL
            );
          ''');
          await db.execute(
              'CREATE INDEX idx_session_timestamp ON scan_sessions(timestamp);');
        }
      },
    );
    return _db!;
  }

  Future<void> upsertNetworks(List<Map<String, dynamic>> networks) async {
    if (networks.isEmpty) return;
    final db = await _open();
    await db.transaction((txn) async {
      for (final n in networks) {
        final bssid = (n['bssid'] as String).toUpperCase();
        final now = n['now'] as int;
        final risk = n['risk'] as String;
        final rows = await txn.query(
          'scan_entries',
          columns: ['id', 'seenCount'],
          where: 'bssid = ?',
          whereArgs: [bssid],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final id = rows.first['id'] as int;
          final seenCount = (rows.first['seenCount'] as int) + 1;
          await txn.update(
            'scan_entries',
            {
              'ssid': n['ssid'],
              'security': n['security'],
              'channel': n['channel'],
              'rssi': n['rssi'],
              'lastSeenAt': now,
              'seenCount': seenCount,
              'risk': risk,
              'source': n['source'] ?? 'live_scan',
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.insert('scan_entries', {
            'ssid': n['ssid'],
            'bssid': bssid,
            'security': n['security'],
            'channel': n['channel'],
            'rssi': n['rssi'],
            'firstSeenAt': now,
            'lastSeenAt': now,
            'seenCount': 1,
            'risk': risk,
            'source': n['source'] ?? 'live_scan',
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> queryLogs({
    int? from,
    int? to,
    String? risk,
    String? security,
    String? ssidLike,
    int? limit,
    int? offset,
  }) async {
    final db = await _open();
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('lastSeenAt >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('lastSeenAt <= ?');
      args.add(to);
    }
    if (risk != null && risk.isNotEmpty) {
      where.add('risk = ?');
      args.add(risk);
    }
    if (security != null && security.isNotEmpty) {
      where.add('security LIKE ?');
      args.add('%$security%');
    }
    if (ssidLike != null && ssidLike.isNotEmpty) {
      where.add('ssid LIKE ?');
      args.add('%$ssidLike%');
    }
    // Always exclude the ESP32 device from logs
    where.add('UPPER(ssid) <> ?');
    args.add('ZYNC_DEVICE');
    final rows = await db.query('scan_entries',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'lastSeenAt DESC',
        limit: limit,
        offset: offset);
    return rows;
  }

  Future<void> clearAll() async {
    final db = await _open();
    await db.delete('scan_entries');
    await db.delete('scan_sessions');
  }

  // Save a scan session with its statistics
  Future<void> saveScanSession({
    required String sessionId,
    required int timestamp,
    required int totalNetworks,
    required int secureNetworks,
    required int vulnerableNetworks,
  }) async {
    final db = await _open();
    await db.insert(
      'scan_sessions',
      {
        'id': sessionId,
        'timestamp': timestamp,
        'totalNetworks': totalNetworks,
        'secureNetworks': secureNetworks,
        'vulnerableNetworks': vulnerableNetworks,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get the most recent scan session statistics
  Future<Map<String, int>?> getLatestScanSession() async {
    final db = await _open();
    final results = await db.query(
      'scan_sessions',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    
    final session = results.first;
    return {
      'total': session['totalNetworks'] as int,
      'secure': session['secureNetworks'] as int,
      'vulnerable': session['vulnerableNetworks'] as int,
    };
  }
}
