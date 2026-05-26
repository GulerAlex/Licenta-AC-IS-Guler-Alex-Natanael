enum AcademicEventType {
  exam,
  colloquium,
  retake,
  project,
  homework,
  lab,
  deadline,
  study;

  String get label {
    return switch (this) {
      AcademicEventType.exam => 'Examen',
      AcademicEventType.colloquium => 'Colocviu',
      AcademicEventType.retake => 'Restanta',
      AcademicEventType.project => 'Proiect',
      AcademicEventType.homework => 'Tema',
      AcademicEventType.lab => 'Laborator',
      AcademicEventType.deadline => 'Deadline',
      AcademicEventType.study => 'Studiu',
    };
  }
}

enum AcademicPriority {
  low,
  medium,
  high;

  String get label {
    return switch (this) {
      AcademicPriority.low => 'Scazuta',
      AcademicPriority.medium => 'Medie',
      AcademicPriority.high => 'Ridicata',
    };
  }
}

enum AcademicEventStatus {
  planned,
  inProgress,
  done,
  cancelled;

  String get storageValue {
    return switch (this) {
      AcademicEventStatus.planned => 'planned',
      AcademicEventStatus.inProgress => 'in_progress',
      AcademicEventStatus.done => 'done',
      AcademicEventStatus.cancelled => 'cancelled',
    };
  }
}

class AcademicEvent {
  const AcademicEvent({
    required this.id,
    required this.subjectId,
    required this.type,
    required this.title,
    required this.startsAt,
    required this.dueAt,
    required this.room,
    required this.notes,
    required this.priority,
    required this.status,
    required this.reminderMinutesBefore,
    required this.notificationsEnabled,
  });

  final String id;
  final String? subjectId;
  final AcademicEventType type;
  final String title;
  final DateTime? startsAt;
  final DateTime? dueAt;
  final String room;
  final String notes;
  final AcademicPriority priority;
  final AcademicEventStatus status;
  final int reminderMinutesBefore;
  final bool notificationsEnabled;

  DateTime? get effectiveDate => dueAt ?? startsAt;

  factory AcademicEvent.fromMap(Map<String, dynamic> map) {
    final String subjectId = (map['subject_id'] as String?)?.trim() ?? '';
    return AcademicEvent(
      id: (map['id'] as String?) ?? '',
      subjectId: subjectId.isEmpty ? null : subjectId,
      type: _eventTypeFromStorage((map['event_type'] as String?) ?? ''),
      title: (map['title'] as String?) ?? '',
      startsAt: _parseDateTime(map['starts_at']),
      dueAt: _parseDateTime(map['due_at']),
      room: (map['room'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      priority: _priorityFromStorage((map['priority'] as String?) ?? ''),
      status: _statusFromStorage((map['status'] as String?) ?? ''),
      reminderMinutesBefore: _parseInt(
        map['reminder_minutes_before'],
        fallback: 1440,
      ).clamp(0, 10080),
      notificationsEnabled: (map['notifications_enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toSupabasePayload({required String userId}) {
    return <String, dynamic>{
      'user_id': userId,
      'subject_id': subjectId,
      'event_type': type.name,
      'title': title.trim(),
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'due_at': dueAt?.toUtc().toIso8601String(),
      'room': room.trim(),
      'notes': notes.trim(),
      'priority': priority.name,
      'status': status.storageValue,
      'reminder_minutes_before': reminderMinutesBefore,
      'notifications_enabled': notificationsEnabled,
    };
  }
}

AcademicEventType _eventTypeFromStorage(String value) {
  return AcademicEventType.values.firstWhere(
    (AcademicEventType type) => type.name == value.trim(),
    orElse: () => AcademicEventType.deadline,
  );
}

AcademicPriority _priorityFromStorage(String value) {
  return AcademicPriority.values.firstWhere(
    (AcademicPriority priority) => priority.name == value.trim(),
    orElse: () => AcademicPriority.medium,
  );
}

AcademicEventStatus _statusFromStorage(String value) {
  return switch (value.trim()) {
    'in_progress' => AcademicEventStatus.inProgress,
    'done' => AcademicEventStatus.done,
    'cancelled' => AcademicEventStatus.cancelled,
    _ => AcademicEventStatus.planned,
  };
}

DateTime? _parseDateTime(dynamic value) {
  return switch (value) {
    DateTime parsed => parsed.toLocal(),
    String parsed => DateTime.tryParse(parsed)?.toLocal(),
    _ => null,
  };
}

int _parseInt(dynamic value, {required int fallback}) {
  return switch (value) {
    int parsed => parsed,
    num parsed => parsed.toInt(),
    String parsed => int.tryParse(parsed) ?? fallback,
    _ => fallback,
  };
}
