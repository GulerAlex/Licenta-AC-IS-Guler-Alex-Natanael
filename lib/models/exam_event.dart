class ExamEvent {
  const ExamEvent({
    required this.id,
    required this.subjectName,
    required this.examType,
    required this.startsAt,
    required this.room,
    required this.notes,
    required this.reminderMinutesBefore,
    required this.notificationsEnabled,
  });

  final String id;
  final String subjectName;
  final String examType;
  final DateTime startsAt;
  final String room;
  final String notes;
  final int reminderMinutesBefore;
  final bool notificationsEnabled;

  factory ExamEvent.fromMap(Map<String, dynamic> map) {
    final dynamic startsAtRaw = map['starts_at'];
    final DateTime parsedStartsAt = switch (startsAtRaw) {
      DateTime value => value.toLocal(),
      String value => DateTime.tryParse(value)?.toLocal() ?? DateTime.now(),
      _ => DateTime.now(),
    };

    final dynamic reminderRaw = map['reminder_minutes_before'];
    final int parsedReminder = switch (reminderRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value) ?? 1440,
      _ => 1440,
    };

    return ExamEvent(
      id: (map['id'] as String?) ?? '',
      subjectName: (map['subject_name'] as String?) ?? '',
      examType: (map['exam_type'] as String?) ?? 'Examen',
      startsAt: parsedStartsAt,
      room: (map['room'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      reminderMinutesBefore: parsedReminder,
      notificationsEnabled: (map['notifications_enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toSupabasePayload({required String userId}) {
    return <String, dynamic>{
      'user_id': userId,
      'subject_name': subjectName.trim(),
      'exam_type': examType.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'room': room.trim(),
      'notes': notes.trim(),
      'reminder_minutes_before': reminderMinutesBefore,
      'notifications_enabled': notificationsEnabled,
    };
  }

  ExamEvent copyWith({
    String? id,
    String? subjectName,
    String? examType,
    DateTime? startsAt,
    String? room,
    String? notes,
    int? reminderMinutesBefore,
    bool? notificationsEnabled,
  }) {
    return ExamEvent(
      id: id ?? this.id,
      subjectName: subjectName ?? this.subjectName,
      examType: examType ?? this.examType,
      startsAt: startsAt ?? this.startsAt,
      room: room ?? this.room,
      notes: notes ?? this.notes,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
