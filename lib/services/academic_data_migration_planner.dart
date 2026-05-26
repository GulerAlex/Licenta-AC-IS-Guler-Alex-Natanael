import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/models/exam_event.dart';
import 'package:unihub/models/grade_component_record.dart';

class AcademicDataMigrationPlan {
  const AcademicDataMigrationPlan({
    required this.subjects,
    required this.classSessionsBySubjectKey,
    required this.eventsBySubjectKey,
    required this.gradeComponentsBySubjectKey,
  });

  final List<AcademicSubjectV2> subjects;
  final Map<String, List<ClassSession>> classSessionsBySubjectKey;
  final Map<String, List<AcademicEvent>> eventsBySubjectKey;
  final Map<String, List<GradeComponentRecord>> gradeComponentsBySubjectKey;
}

class AcademicDataMigrationPlanner {
  const AcademicDataMigrationPlanner();

  AcademicDataMigrationPlan buildPlan({
    required List<Course> courses,
    required List<ExamEvent> exams,
    required Map<String, double> weights,
    required Map<String, double> grades,
  }) {
    final Map<String, List<Course>> coursesBySubjectKey =
        <String, List<Course>>{};
    for (final Course course in courses) {
      if (_isPendingCourse(course) || course.name.trim().isEmpty) {
        continue;
      }
      coursesBySubjectKey
          .putIfAbsent(_subjectKey(course.name, course.semesterLabel), () => [])
          .add(course);
    }

    final List<AcademicSubjectV2> subjects = coursesBySubjectKey.entries
        .map((MapEntry<String, List<Course>> entry) {
          final List<Course> subjectCourses = entry.value;
          final Course reference = subjectCourses.first;
          final int credits = subjectCourses.fold<int>(
            reference.credits,
            (int currentMax, Course course) =>
                course.credits > currentMax ? course.credits : currentMax,
          );
          final String professor = subjectCourses
              .map((Course course) => course.professor.trim())
              .firstWhere(
                (String value) => value.isNotEmpty && value != '-',
                orElse: () => '',
              );

          return AcademicSubjectV2(
            id: '',
            name: reference.name.trim(),
            semesterLabel: reference.semesterLabel.trim(),
            credits: credits,
            professor: professor,
            colorHex: '#35B86F',
            archived: false,
          );
        })
        .toList(growable: false);

    final Map<String, List<ClassSession>> sessionsBySubjectKey =
        <String, List<ClassSession>>{};
    coursesBySubjectKey.forEach((String key, List<Course> subjectCourses) {
      final List<ClassSession> sessions = subjectCourses
          .map(_classSessionFromCourse)
          .whereType<ClassSession>()
          .toList(growable: false);
      if (sessions.isNotEmpty) {
        sessionsBySubjectKey[key] = sessions;
      }
    });

    final Map<String, String> firstSubjectKeyByName = <String, String>{};
    for (final AcademicSubjectV2 subject in subjects) {
      firstSubjectKeyByName.putIfAbsent(
        _normalizeName(subject.name),
        () => _subjectKey(subject.name, subject.semesterLabel),
      );
    }

    final Map<String, List<AcademicEvent>> eventsBySubjectKey =
        <String, List<AcademicEvent>>{};
    for (final ExamEvent exam in exams) {
      final String? subjectKey =
          firstSubjectKeyByName[_normalizeName(exam.subjectName)];
      if (subjectKey == null) {
        continue;
      }
      eventsBySubjectKey
          .putIfAbsent(subjectKey, () => <AcademicEvent>[])
          .add(_academicEventFromExam(exam));
    }

    final Map<String, List<GradeComponentRecord>> componentsBySubjectKey =
        <String, List<GradeComponentRecord>>{};
    for (final AcademicSubjectV2 subject in subjects) {
      final String key = _subjectKey(subject.name, subject.semesterLabel);
      final Set<String> componentNames = <String>{
        ...coursesBySubjectKey[key]!.map(
          (Course course) => _canonicalComponentName(course.courseType),
        ),
        ...weights.keys
            .where((String itemKey) => itemKey.startsWith('${subject.name}|'))
            .map(
              (String itemKey) =>
                  _canonicalComponentName(itemKey.split('|').last),
            ),
        ...grades.keys
            .where((String itemKey) => itemKey.startsWith('${subject.name}|'))
            .map(
              (String itemKey) =>
                  _canonicalComponentName(itemKey.split('|').last),
            ),
      }..removeWhere((String value) => value.trim().isEmpty);

      if (componentNames.isEmpty) {
        componentNames.add('Examen');
      }

      componentsBySubjectKey[key] = componentNames
          .map(
            (String componentName) => _gradeComponentFromLegacy(
              subjectName: subject.name,
              componentName: componentName,
              weights: weights,
              grades: grades,
            ),
          )
          .toList(growable: false);
    }

    return AcademicDataMigrationPlan(
      subjects: subjects,
      classSessionsBySubjectKey: sessionsBySubjectKey,
      eventsBySubjectKey: eventsBySubjectKey,
      gradeComponentsBySubjectKey: componentsBySubjectKey,
    );
  }

  String subjectKeyFor(AcademicSubjectV2 subject) {
    return _subjectKey(subject.name, subject.semesterLabel);
  }

  ClassSession? _classSessionFromCourse(Course course) {
    final int? weekday = _weekdayFromLabel(course.weekdayLabel);
    final _TimeRange? timeRange = _parseTimeRange(course.time);
    if (weekday == null || timeRange == null) {
      return null;
    }

    return ClassSession(
      id: '',
      subjectId: '',
      sessionType: _canonicalSessionType(course.courseType),
      weekday: weekday,
      startsAtMinutes: timeRange.startMinutes,
      endsAtMinutes: timeRange.endMinutes,
      room: course.room.trim() == '-' ? '' : course.room.trim(),
      professor: course.professor.trim() == '-' ? '' : course.professor.trim(),
      active: true,
    );
  }

  AcademicEvent _academicEventFromExam(ExamEvent exam) {
    return AcademicEvent(
      id: '',
      subjectId: null,
      type: _eventTypeFromExamType(exam.examType),
      title:
          '${exam.examType.trim().isEmpty ? 'Examen' : exam.examType.trim()} - ${exam.subjectName.trim()}',
      startsAt: exam.startsAt,
      dueAt: exam.startsAt,
      room: exam.room,
      notes: exam.notes,
      priority: AcademicPriority.high,
      status: AcademicEventStatus.planned,
      reminderMinutesBefore: exam.reminderMinutesBefore,
      notificationsEnabled: exam.notificationsEnabled,
    );
  }

  GradeComponentRecord _gradeComponentFromLegacy({
    required String subjectName,
    required String componentName,
    required Map<String, double> weights,
    required Map<String, double> grades,
  }) {
    final String legacyType = componentName == 'Examen'
        ? 'Curs'
        : componentName;
    final double? grade =
        grades['$subjectName|$componentName'] ??
        grades['$subjectName|$legacyType'];
    final double weight =
        weights['$subjectName|$componentName'] ??
        weights['$subjectName|$legacyType'] ??
        0;

    return GradeComponentRecord(
      id: '',
      subjectId: '',
      name: componentName,
      type: _componentTypeFromLabel(componentName),
      weightPercent: weight,
      minimumGrade: 5,
      grade: grade,
      isRequired: true,
      isEliminatory: _isEliminatoryComponent(componentName),
    );
  }

  bool _isPendingCourse(Course course) {
    return course.time == UniHubRepository.pendingCourseTimeLabel;
  }

  String _subjectKey(String name, String semesterLabel) {
    return '${_normalizeName(name)}|${semesterLabel.trim()}';
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }

  String _canonicalSessionType(String label) {
    return switch (label.trim()) {
      'Seminar' => 'Seminar',
      'Laborator' => 'Laborator',
      _ => 'Curs',
    };
  }

  String _canonicalComponentName(String label) {
    return switch (label.trim()) {
      'Curs' => 'Examen',
      String value when value.isNotEmpty => value,
      _ => 'Alta componenta',
    };
  }

  GradeComponentRecordType _componentTypeFromLabel(String label) {
    return switch (label.trim()) {
      'Examen' => GradeComponentRecordType.exam,
      'Seminar' => GradeComponentRecordType.seminar,
      'Laborator' => GradeComponentRecordType.laboratory,
      'Proiect' => GradeComponentRecordType.project,
      'Activitate pe parcurs' => GradeComponentRecordType.coursework,
      _ => GradeComponentRecordType.other,
    };
  }

  bool _isEliminatoryComponent(String label) {
    return switch (_componentTypeFromLabel(label)) {
      GradeComponentRecordType.seminar ||
      GradeComponentRecordType.laboratory ||
      GradeComponentRecordType.project => true,
      _ => false,
    };
  }

  AcademicEventType _eventTypeFromExamType(String label) {
    return switch (label.trim().toLowerCase()) {
      'colocviu' => AcademicEventType.colloquium,
      'restanta' || 'restanță' => AcademicEventType.retake,
      'proiect' => AcademicEventType.project,
      _ => AcademicEventType.exam,
    };
  }

  int? _weekdayFromLabel(String label) {
    return switch (label.trim()) {
      'Luni' => DateTime.monday,
      'Marti' => DateTime.tuesday,
      'Miercuri' => DateTime.wednesday,
      'Joi' => DateTime.thursday,
      'Vineri' => DateTime.friday,
      'Sambata' => DateTime.saturday,
      'Duminica' => DateTime.sunday,
      _ => null,
    };
  }

  _TimeRange? _parseTimeRange(String value) {
    final RegExpMatch? match = RegExp(
      r'^(\d{1,2})\s*:\s*(\d{2})\s*-\s*(\d{1,2})\s*:\s*(\d{2})$',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }

    final int? startHour = int.tryParse(match.group(1) ?? '');
    final int? startMinute = int.tryParse(match.group(2) ?? '');
    final int? endHour = int.tryParse(match.group(3) ?? '');
    final int? endMinute = int.tryParse(match.group(4) ?? '');
    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null) {
      return null;
    }
    if (startHour < 0 ||
        startHour > 23 ||
        endHour < 0 ||
        endHour > 23 ||
        startMinute < 0 ||
        startMinute > 59 ||
        endMinute < 0 ||
        endMinute > 59) {
      return null;
    }

    final int start = (startHour * 60) + startMinute;
    final int end = (endHour * 60) + endMinute;
    if (end <= start) {
      return null;
    }
    return _TimeRange(startMinutes: start, endMinutes: end);
  }
}

class _TimeRange {
  const _TimeRange({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;
}
