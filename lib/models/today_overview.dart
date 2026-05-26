import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/models/study_task.dart';

class TodayOverview {
  const TodayOverview({
    required this.nextClass,
    required this.todayClasses,
    required this.upcomingEvents,
    required this.openTasks,
    required this.risks,
    required this.hasAnyData,
  });

  final TodayClassItem? nextClass;
  final List<TodayClassItem> todayClasses;
  final List<TodayEventItem> upcomingEvents;
  final List<TodayTaskItem> openTasks;
  final List<TodayRiskItem> risks;
  final bool hasAnyData;
}

class TodayClassItem {
  const TodayClassItem({required this.subject, required this.session});

  final AcademicSubjectV2 subject;
  final ClassSession session;
}

class TodayEventItem {
  const TodayEventItem({required this.subject, required this.event});

  final AcademicSubjectV2? subject;
  final AcademicEvent event;
}

class TodayTaskItem {
  const TodayTaskItem({required this.subject, required this.task});

  final AcademicSubjectV2? subject;
  final StudyTask task;
}

class TodayRiskItem {
  const TodayRiskItem({
    required this.subject,
    required this.component,
    required this.message,
    required this.severity,
  });

  final AcademicSubjectV2 subject;
  final GradeComponentRecord component;
  final String message;
  final TodayRiskSeverity severity;
}

enum TodayRiskSeverity { medium, high }
