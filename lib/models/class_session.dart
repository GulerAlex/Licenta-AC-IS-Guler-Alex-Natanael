class ClassSession {
  const ClassSession({
    required this.id,
    required this.subjectId,
    required this.sessionType,
    required this.weekday,
    required this.startsAtMinutes,
    required this.endsAtMinutes,
    required this.room,
    required this.professor,
    required this.active,
  });

  final String id;
  final String subjectId;
  final String sessionType;
  final int weekday;
  final int startsAtMinutes;
  final int endsAtMinutes;
  final String room;
  final String professor;
  final bool active;

  String get startsAtTimeLabel => _formatMinutes(startsAtMinutes);
  String get endsAtTimeLabel => _formatMinutes(endsAtMinutes);
  String get intervalLabel => '$startsAtTimeLabel - $endsAtTimeLabel';

  factory ClassSession.fromMap(Map<String, dynamic> map) {
    return ClassSession(
      id: (map['id'] as String?) ?? '',
      subjectId: (map['subject_id'] as String?) ?? '',
      sessionType: (map['session_type'] as String?) ?? 'Curs',
      weekday: _parseInt(map['weekday'], fallback: 1).clamp(1, 7),
      startsAtMinutes: _parseTimeToMinutes(map['starts_at_time']),
      endsAtMinutes: _parseTimeToMinutes(map['ends_at_time']),
      room: (map['room'] as String?) ?? '',
      professor: (map['professor'] as String?) ?? '',
      active: (map['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toSupabasePayload({required String userId}) {
    return <String, dynamic>{
      'user_id': userId,
      'subject_id': subjectId,
      'session_type': sessionType.trim(),
      'weekday': weekday,
      'starts_at_time': startsAtTimeLabel,
      'ends_at_time': endsAtTimeLabel,
      'room': room.trim(),
      'professor': professor.trim(),
      'recurrence': 'weekly',
      'active': active,
    };
  }

  ClassSession copyWith({
    String? id,
    String? subjectId,
    String? sessionType,
    int? weekday,
    int? startsAtMinutes,
    int? endsAtMinutes,
    String? room,
    String? professor,
    bool? active,
  }) {
    return ClassSession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      sessionType: sessionType ?? this.sessionType,
      weekday: weekday ?? this.weekday,
      startsAtMinutes: startsAtMinutes ?? this.startsAtMinutes,
      endsAtMinutes: endsAtMinutes ?? this.endsAtMinutes,
      room: room ?? this.room,
      professor: professor ?? this.professor,
      active: active ?? this.active,
    );
  }
}

int _parseInt(dynamic value, {required int fallback}) {
  return switch (value) {
    int parsed => parsed,
    num parsed => parsed.toInt(),
    String parsed => int.tryParse(parsed) ?? fallback,
    _ => fallback,
  };
}

int _parseTimeToMinutes(dynamic value) {
  final String text = switch (value) {
    DateTime parsed =>
      '${parsed.hour.toString().padLeft(2, '0')}:'
          '${parsed.minute.toString().padLeft(2, '0')}',
    String parsed => parsed,
    _ => '00:00',
  };
  final RegExpMatch? match = RegExp(
    r'^(\d{1,2}):(\d{2})',
  ).firstMatch(text.trim());
  if (match == null) {
    return 0;
  }
  final int hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final int minute = int.tryParse(match.group(2) ?? '') ?? 0;
  return ((hour.clamp(0, 23) * 60) + minute.clamp(0, 59)).clamp(0, 1439);
}

String _formatMinutes(int minutes) {
  final int normalized = minutes.clamp(0, 1439);
  final int hour = normalized ~/ 60;
  final int minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
