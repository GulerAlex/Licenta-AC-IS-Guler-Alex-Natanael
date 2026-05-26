import 'package:flutter_test/flutter_test.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/models/study_task.dart';

void main() {
  test('AcademicSubjectV2 parses Supabase rows and builds payloads', () {
    final AcademicSubjectV2 subject =
        AcademicSubjectV2.fromMap(<String, dynamic>{
          'id': 'subject-1',
          'name': ' Baze de date ',
          'semester_label': 'Semestrul 2',
          'credits': '6',
          'professor': 'Prof. Test',
          'color_hex': '#123456',
          'archived': false,
        });

    expect(subject.credits, 6);
    expect(
      subject.toSupabasePayload(userId: 'user-1'),
      containsPair('name', 'Baze de date'),
    );
  });

  test('ClassSession keeps time as minutes and payload as HH:mm', () {
    final ClassSession session = ClassSession.fromMap(<String, dynamic>{
      'id': 'session-1',
      'subject_id': 'subject-1',
      'session_type': 'Laborator',
      'weekday': 3,
      'starts_at_time': '08:30:00',
      'ends_at_time': '10:00:00',
      'room': 'C308',
      'professor': 'Prof. Test',
      'active': true,
    });

    expect(session.startsAtMinutes, 510);
    expect(session.intervalLabel, '08:30 - 10:00');
    expect(
      session.toSupabasePayload(userId: 'user-1'),
      containsPair('ends_at_time', '10:00'),
    );
  });

  test('AcademicEvent parses storage enums and dates', () {
    final AcademicEvent event = AcademicEvent.fromMap(<String, dynamic>{
      'id': 'event-1',
      'subject_id': 'subject-1',
      'event_type': 'exam',
      'title': 'Examen final',
      'starts_at': '2026-06-20T09:00:00Z',
      'due_at': null,
      'room': 'A1',
      'notes': '',
      'priority': 'high',
      'status': 'in_progress',
      'reminder_minutes_before': 1440,
      'notifications_enabled': true,
    });

    expect(event.type, AcademicEventType.exam);
    expect(event.priority, AcademicPriority.high);
    expect(event.status, AcademicEventStatus.inProgress);
    expect(event.effectiveDate, isNotNull);
  });

  test('GradeComponentRecord rejects invalid stored grades as null', () {
    final GradeComponentRecord component =
        GradeComponentRecord.fromMap(<String, dynamic>{
          'id': 'grade-1',
          'subject_id': 'subject-1',
          'name': 'Examen',
          'component_type': 'exam',
          'weight_percent': 70,
          'minimum_grade': 5,
          'grade': 11,
          'is_required': true,
          'is_eliminatory': true,
        });

    expect(component.grade, isNull);
    expect(component.type, GradeComponentRecordType.exam);
  });

  test('StudyTask converts in_progress status both ways', () {
    final StudyTask task = StudyTask.fromMap(<String, dynamic>{
      'id': 'task-1',
      'subject_id': '',
      'academic_event_id': '',
      'title': 'Invata capitolul 1',
      'due_at': '2026-06-10T10:00:00Z',
      'estimated_minutes': '45',
      'priority': 'medium',
      'status': 'in_progress',
      'reminder_minutes_before': 60,
      'notifications_enabled': true,
    });

    expect(task.status, StudyTaskStatus.inProgress);
    expect(task.subjectId, isNull);
    expect(
      task.toSupabasePayload(userId: 'user-1'),
      containsPair('status', 'in_progress'),
    );
  });
}
