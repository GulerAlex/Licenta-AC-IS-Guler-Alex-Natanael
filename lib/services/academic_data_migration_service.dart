import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/services/academic_data_migration_planner.dart';

class AcademicDataMigrationResult {
  const AcademicDataMigrationResult({
    required this.subjectsCreatedOrUpdated,
    required this.classSessionsCreated,
    required this.academicEventsCreated,
    required this.gradeComponentsCreated,
  });

  final int subjectsCreatedOrUpdated;
  final int classSessionsCreated;
  final int academicEventsCreated;
  final int gradeComponentsCreated;
}

class AcademicDataMigrationService {
  AcademicDataMigrationService({
    UniHubRepository? repository,
    AcademicDataMigrationPlanner? planner,
  }) : _repository = repository ?? UniHubRepository.instance,
       _planner = planner ?? const AcademicDataMigrationPlanner();

  final UniHubRepository _repository;
  final AcademicDataMigrationPlanner _planner;

  Future<AcademicDataMigrationResult> migrateLegacyDataToV2() async {
    final plan = _planner.buildPlan(
      courses: await _repository.fetchUserCourses(),
      exams: await _repository.fetchExamEvents(),
      weights: await _repository.fetchGradeTypeWeights(),
      grades: await _repository.fetchGradeTypeGrades(),
    );

    int subjectsCreatedOrUpdated = 0;
    int classSessionsCreated = 0;
    int academicEventsCreated = 0;
    int gradeComponentsCreated = 0;

    for (final AcademicSubjectV2 subjectDraft in plan.subjects) {
      final AcademicSubjectV2 savedSubject = await _repository.upsertSubjectV2(
        subjectDraft,
      );
      subjectsCreatedOrUpdated += 1;

      final String subjectKey = _planner.subjectKeyFor(subjectDraft);
      final List<ClassSession> sessions =
          plan.classSessionsBySubjectKey[subjectKey] ?? <ClassSession>[];
      for (final ClassSession session in sessions) {
        await _repository.upsertClassSessionV2(
          session.copyWith(subjectId: savedSubject.id),
        );
        classSessionsCreated += 1;
      }

      final List<AcademicEvent> events =
          plan.eventsBySubjectKey[subjectKey] ?? <AcademicEvent>[];
      for (final AcademicEvent event in events) {
        await _repository.upsertAcademicEventV2(
          AcademicEvent(
            id: event.id,
            subjectId: savedSubject.id,
            type: event.type,
            title: event.title,
            startsAt: event.startsAt,
            dueAt: event.dueAt,
            room: event.room,
            notes: event.notes,
            priority: event.priority,
            status: event.status,
            reminderMinutesBefore: event.reminderMinutesBefore,
            notificationsEnabled: event.notificationsEnabled,
          ),
        );
        academicEventsCreated += 1;
      }

      final List<GradeComponentRecord> components =
          plan.gradeComponentsBySubjectKey[subjectKey] ??
          <GradeComponentRecord>[];
      for (final GradeComponentRecord component in components) {
        await _repository.upsertGradeComponentV2(
          GradeComponentRecord(
            id: component.id,
            subjectId: savedSubject.id,
            name: component.name,
            type: component.type,
            weightPercent: component.weightPercent,
            minimumGrade: component.minimumGrade,
            grade: component.grade,
            isRequired: component.isRequired,
            isEliminatory: component.isEliminatory,
          ),
        );
        gradeComponentsCreated += 1;
      }
    }

    return AcademicDataMigrationResult(
      subjectsCreatedOrUpdated: subjectsCreatedOrUpdated,
      classSessionsCreated: classSessionsCreated,
      academicEventsCreated: academicEventsCreated,
      gradeComponentsCreated: gradeComponentsCreated,
    );
  }
}
