import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/audit_event.dart';
import 'audit_redactor.dart';

/// Query filter; null fields mean "no constraint".
class AuditFilter {
  final String? hostId;
  final String? type;
  final int? fromTs;
  final int? toTs;
  final String? search;
  const AuditFilter(
      {this.hostId, this.type, this.fromTs, this.toTs, this.search});

  (String, List<Object?>) toWhere() {
    final clauses = <String>[];
    final args = <Object?>[];
    if (hostId != null) {
      clauses.add('host_id = ?');
      args.add(hostId);
    }
    if (type != null) {
      clauses.add('type = ?');
      args.add(type);
    }
    if (fromTs != null) {
      clauses.add('ts >= ?');
      args.add(fromTs);
    }
    if (toTs != null) {
      clauses.add('ts <= ?');
      args.add(toTs);
    }
    final s = search?.trim();
    if (s != null && s.isNotEmpty) {
      clauses.add('(command LIKE ? OR host_label LIKE ?)');
      args
        ..add('%$s%')
        ..add('%$s%');
    }
    return (clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}', args);
  }
}

/// Append-only audit trail in a local SQLite DB. Every write is fail-soft:
/// auditing must never break an SSH operation, so errors are logged and
/// swallowed. See docs/superpowers/specs/2026-06-06-internal-audit-log-design.md.
class AuditService {
  Database? _db;
  String? initError;
  bool get isAvailable => _db != null;

  static const _schema = '''
CREATE TABLE IF NOT EXISTS audit_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL,
  type TEXT NOT NULL,
  host_id TEXT,
  host_label TEXT,
  username TEXT,
  session_id TEXT,
  command TEXT,
  exit_code INTEGER,
  meta TEXT
)''';

  /// Open (or create) the on-disk DB under the app-support directory.
  /// Fail-soft: a failure leaves the service disabled with [initError] set.
  Future<void> init({String? dbPath}) async {
    try {
      final path = dbPath ??
          p.join((await getApplicationSupportDirectory()).path, 'audit.db');
      _open(sqlite3.open(path));
    } catch (e) {
      initError = '$e';
      debugPrint('[AuditService] init failed: $e');
    }
  }

  /// In-memory DB for tests.
  void initInMemory() => _open(sqlite3.openInMemory());

  void _open(Database db) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute(_schema);
    db.execute('CREATE INDEX IF NOT EXISTS idx_audit_ts ON audit_events(ts)');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_host ON audit_events(host_id)');
    _db = db;
  }

  void record(AuditEvent e) {
    final db = _db;
    if (db == null) return;
    try {
      db.execute(
        'INSERT INTO audit_events '
        '(ts, type, host_id, host_label, username, session_id, command, '
        'exit_code, meta) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          e.ts.millisecondsSinceEpoch,
          e.type.name,
          e.hostId,
          e.hostLabel,
          e.username,
          e.sessionId,
          e.command == null ? null : AuditRedactor.redact(e.command!),
          e.exitCode,
          e.meta.isEmpty ? null : jsonEncode(e.meta),
        ],
      );
    } catch (err) {
      debugPrint('[AuditService] record failed: $err'); // never rethrow
    }
  }

  List<AuditEvent> query(AuditFilter f, {int limit = 200, int offset = 0}) {
    final db = _db;
    if (db == null) return const [];
    try {
      final (where, args) = f.toWhere();
      final rows = db.select(
        'SELECT * FROM audit_events $where '
        'ORDER BY ts DESC, id DESC LIMIT ? OFFSET ?',
        [...args, limit, offset],
      );
      return rows.map(AuditEvent.fromRow).toList();
    } catch (err) {
      debugPrint('[AuditService] query failed: $err');
      return const [];
    }
  }

  /// Delete rows older than [retentionDays]; `<= 0` keeps forever.
  void prune(int retentionDays) {
    if (retentionDays <= 0) return;
    try {
      _db?.execute('DELETE FROM audit_events WHERE ts < ?', [
        DateTime.now()
            .subtract(Duration(days: retentionDays))
            .millisecondsSinceEpoch
      ]);
    } catch (err) {
      debugPrint('[AuditService] prune failed: $err');
    }
  }

  void clearAll() {
    try {
      _db?.execute('DELETE FROM audit_events');
    } catch (err) {
      debugPrint('[AuditService] clearAll failed: $err');
    }
  }

  List<AuditEvent> _allMatching(AuditFilter f) {
    final db = _db;
    if (db == null) return const [];
    final (where, args) = f.toWhere();
    final rows = db.select(
        'SELECT * FROM audit_events $where ORDER BY ts DESC, id DESC', args);
    return rows.map(AuditEvent.fromRow).toList();
  }

  static String _csvField(String v) =>
      (v.contains(',') || v.contains('"') || v.contains('\n'))
          ? '"${v.replaceAll('"', '""')}"'
          : v;

  String exportCsv(AuditFilter f) {
    const header = 'ts,type,host_label,username,session_id,command,'
        'exit_code,meta';
    final lines = [
      header,
      for (final e in _allMatching(f)) e.toCsvRow().map(_csvField).join(','),
    ];
    return lines.join('\n');
  }

  String exportJson(AuditFilter f) =>
      jsonEncode([for (final e in _allMatching(f)) e.toJson()]);

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
