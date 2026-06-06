import 'dart:convert';

import 'host.dart';

enum AuditEventType { connect, disconnect, exec, input }

/// One immutable audit-log row. Host fields are denormalized at record
/// time — the host may be renamed or deleted later.
class AuditEvent {
  final int? id;
  final DateTime ts;
  final AuditEventType type;
  final String? hostId;
  final String? hostLabel;
  final String? username;
  final String? sessionId;
  final String? command;
  final int? exitCode;
  final Map<String, dynamic> meta;

  const AuditEvent({
    this.id,
    required this.ts,
    required this.type,
    this.hostId,
    this.hostLabel,
    this.username,
    this.sessionId,
    this.command,
    this.exitCode,
    this.meta = const {},
  });

  AuditEvent.now({
    required this.type,
    Host? host,
    this.sessionId,
    this.command,
    this.exitCode,
    this.meta = const {},
  })  : id = null,
        ts = DateTime.now(),
        hostId = host?.id,
        hostLabel = host?.label,
        username = host?.username;

  factory AuditEvent.fromRow(Map<String, dynamic> r) => AuditEvent(
        id: r['id'] as int?,
        ts: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
        type: AuditEventType.values.byName(r['type'] as String),
        hostId: r['host_id'] as String?,
        hostLabel: r['host_label'] as String?,
        username: r['username'] as String?,
        sessionId: r['session_id'] as String?,
        command: r['command'] as String?,
        exitCode: r['exit_code'] as int?,
        meta: r['meta'] == null
            ? const {}
            : (jsonDecode(r['meta'] as String) as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'ts': ts.toIso8601String(),
        'type': type.name,
        'hostId': hostId,
        'hostLabel': hostLabel,
        'username': username,
        'sessionId': sessionId,
        'command': command,
        'exitCode': exitCode,
        'meta': meta,
      };

  List<String> toCsvRow() => [
        ts.toIso8601String(),
        type.name,
        hostLabel ?? '',
        username ?? '',
        sessionId ?? '',
        command ?? '',
        exitCode?.toString() ?? '',
        meta.isEmpty ? '' : jsonEncode(meta),
      ];
}
