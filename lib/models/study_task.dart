import 'package:unihub/models/academic_event.dart';

enum StudyTaskStatus {
  todo,
  inProgress,
  done,
  cancelled;

  String get storageValue {
    return switch (this) {
      StudyTaskStatus.todo => 'todo',
      StudyTaskStatus.inProgress => 'in_progress',
      StudyTaskStatus.done => 'done',
      StudyTaskStatus.cancelled => 'cancelled',
    };
  }
}

class StudyTask {
  const StudyTask({
    required this.id,
    required this.subjectId,
    required this.academicEventId,
    required this.title,
    required this.dueAt,
    required this.estimatedMinutes,
    required this.priority,
    required this.status,
    required this.reminderMinutesBefore,
    required this.notificationsEnabled,
  });

  final String id;
  final String? subjectId;
  final String? academicEventId;
  final String title;
  final DateTime? dueAt;
  final int? estimatedMinutes;
  final AcademicPriority priority;
  final StudyTaskStatus status;
  final int? reminderMinutesBefore;
  final bool notificationsEnabled;

  factory StudyTask.fromMap(Map<String, dynamic> map) {
    final String subjectId = (map['subject_id'] as String?)?.trim() ?? '';
    final String academicEventId =
        (map['academic_event_id'] as String?)?.trim() ?? '';
    return StudyTask(
      id: (map['id'] as String?) ?? '',
      subjectId: subjectId.isEmpty ? null : subjectId,
      academicEventId: academicEventId.isEmpty ? null : academicEventId,
      title: (map['title'] as String?) ?? '',
      dueAt: _parseDateTime(map['due_at']),
      estimatedMinutes: _parseNullableInt(map['estimated_minutes']),
      priority: _priorityFromStorage((map['priority'] as String?) ?? ''),
      status: _statusFromStorage((map['status'] as String?) ?? ''),
      reminderMinutesBefore: _parseNullableInt(map['reminder_minutes_before']),
      notificationsEnabled: (map['notifications_enabled'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toSupabasePayload({required String userId}) {
    return <String, dynamic>{
      'user_id': userId,
      'subject_id': subjectId,
      'academic_event_id': academicEventId,
      'title': title.trim(),
      'due_at': dueAt?.toUtc().toIso8601String(),
      'estimated_minutes': estimatedMinutes,
      'priority': priority.name,
      'status': status.storageValue,
      'reminder_minutes_before': reminderMinutesBefore,
      'notifications_enabled': notificationsEnabled,
    };
  }
}

AcademicPriority _priorityFromStorage(String value) {
  return AcademicPriority.values.firstWhere(
    (AcademicPriority priority) => priority.name == value.trim(),
    orElse: () => AcademicPriority.medium,
  );
}

StudyTaskStatus _statusFromStorage(String value) {
  return switch (value.trim()) {
    'in_progress' => StudyTaskStatus.inProgress,
    'done' => StudyTaskStatus.done,
    'cancelled' => StudyTaskStatus.cancelled,
    _ => StudyTaskStatus.todo,
  };
}

DateTime? _parseDateTime(dynamic value) {
  return switch (value) {
    DateTime parsed => parsed.toLocal(),
    String parsed => DateTime.tryParse(parsed)?.toLocal(),
    _ => null,
  };
}

int? _parseNullableInt(dynamic value) {
  final int? parsed = switch (value) {
    int parsed => parsed,
    num parsed => parsed.toInt(),
    String parsed => int.tryParse(parsed),
    _ => null,
  };
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}
