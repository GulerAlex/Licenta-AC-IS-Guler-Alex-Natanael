import 'package:flutter_test/flutter_test.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/models/exam_event.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/services/academic_data_migration_planner.dart';

void main() {
  const AcademicDataMigrationPlanner planner = AcademicDataMigrationPlanner();

  test('buildPlan groups legacy courses into subjects and class sessions', () {
    final AcademicDataMigrationPlan plan = planner.buildPlan(
      courses: <Course>[
        const Course(
          name: 'Baze de date',
          semesterLabel: 'Semestrul 2',
          credits: 6,
          courseType: 'Curs',
          weekdayLabel: 'Luni',
          time: '08:00 - 10:00',
          room: 'A1',
          professor: 'Prof. DB',
          sortOrder: 480,
        ),
        const Course(
          name: 'Baze de date',
          semesterLabel: 'Semestrul 2',
          credits: 6,
          courseType: 'Laborator',
          weekdayLabel: 'Marti',
          time: '10:00 - 12:00',
          room: 'C308',
          professor: 'Asist. DB',
          sortOrder: 600,
        ),
        const Course(
          name: 'Draft',
          semesterLabel: 'Semestrul 2',
          credits: 5,
          courseType: 'Curs',
          weekdayLabel: 'Luni',
          time: UniHubRepository.pendingCourseTimeLabel,
          room: '-',
          professor: '-',
          sortOrder: 9999,
        ),
      ],
      exams: const <ExamEvent>[],
      weights: const <String, double>{},
      grades: const <String, double>{},
    );

    expect(plan.subjects, hasLength(1));
    expect(plan.subjects.first.name, 'Baze de date');
    expect(plan.subjects.first.professor, 'Prof. DB');

    final String subjectKey = planner.subjectKeyFor(plan.subjects.first);
    final List<ClassSession> sessions =
        plan.classSessionsBySubjectKey[subjectKey] ?? <ClassSession>[];
    expect(sessions, hasLength(2));
    expect(sessions.first.startsAtMinutes, 480);
    expect(sessions.last.sessionType, 'Laborator');
  });

  test('buildPlan migrates exams and grade components to subject keys', () {
    final DateTime startsAt = DateTime(2026, 6, 20, 9);
    final AcademicDataMigrationPlan plan = planner.buildPlan(
      courses: <Course>[
        const Course(
          name: 'Structuri de date',
          semesterLabel: 'Semestrul 1',
          credits: 5,
          courseType: 'Curs',
          weekdayLabel: 'Miercuri',
          time: '12:00 - 14:00',
          room: 'B2',
          professor: 'Prof. SD',
          sortOrder: 720,
        ),
        const Course(
          name: 'Structuri de date',
          semesterLabel: 'Semestrul 1',
          credits: 5,
          courseType: 'Seminar',
          weekdayLabel: 'Joi',
          time: '14:00 - 16:00',
          room: 'S1',
          professor: 'Asist. SD',
          sortOrder: 840,
        ),
      ],
      exams: <ExamEvent>[
        ExamEvent(
          id: 'exam-1',
          subjectName: 'Structuri de date',
          examType: 'Examen',
          startsAt: startsAt,
          room: 'Aula',
          notes: 'Capitolele 1-8',
          reminderMinutesBefore: 1440,
          notificationsEnabled: true,
        ),
      ],
      weights: const <String, double>{
        'Structuri de date|Curs': 70,
        'Structuri de date|Seminar': 30,
      },
      grades: const <String, double>{'Structuri de date|Seminar': 8},
    );

    final String subjectKey = planner.subjectKeyFor(plan.subjects.first);
    final List<AcademicEvent> events =
        plan.eventsBySubjectKey[subjectKey] ?? <AcademicEvent>[];
    final List<GradeComponentRecord> components =
        plan.gradeComponentsBySubjectKey[subjectKey] ??
        <GradeComponentRecord>[];

    expect(events, hasLength(1));
    expect(events.first.type, AcademicEventType.exam);
    expect(events.first.priority, AcademicPriority.high);

    expect(
      components.map((GradeComponentRecord item) => item.name),
      contains('Examen'),
    );
    final GradeComponentRecord exam = components.firstWhere(
      (GradeComponentRecord item) => item.name == 'Examen',
    );
    final GradeComponentRecord seminar = components.firstWhere(
      (GradeComponentRecord item) => item.name == 'Seminar',
    );
    expect(exam.weightPercent, 70);
    expect(seminar.grade, 8);
    expect(seminar.isEliminatory, isTrue);
  });
}
