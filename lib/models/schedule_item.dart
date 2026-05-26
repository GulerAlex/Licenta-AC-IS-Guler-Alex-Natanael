import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';

class ScheduleClassItem {
  const ScheduleClassItem({required this.subject, required this.session});

  final AcademicSubjectV2 subject;
  final ClassSession session;

  String get professor {
    final String sessionProfessor = session.professor.trim();
    if (sessionProfessor.isNotEmpty) {
      return sessionProfessor;
    }
    return subject.professor.trim();
  }
}

class ScheduleEventItem {
  const ScheduleEventItem({required this.event, required this.subject});

  final AcademicEvent event;
  final AcademicSubjectV2? subject;

  String get title {
    final String eventTitle = event.title.trim();
    if (eventTitle.isNotEmpty) {
      return eventTitle;
    }
    return event.type.label;
  }

  String get subjectName => subject?.name.trim() ?? '';
}
