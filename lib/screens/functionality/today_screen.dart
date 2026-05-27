import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/models/study_task.dart';
import 'package:unihub/models/today_overview.dart';
import 'package:unihub/screens/ui/today_screen_view.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenSubjects,
  });

  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenSubjects;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  late Future<TodayOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  Future<void> _reload() async {
    setState(() {
      _overviewFuture = _loadOverview();
    });
    await _overviewFuture;
  }

  Future<List<T>> _loadTodaySection<T>(
    String label,
    Future<List<T>> Function() load,
  ) async {
    try {
      return await load();
    } catch (e, stackTrace) {
      debugPrint('Failed to load Today $label: $e');
      debugPrint('Failed to load Today $label stack: $stackTrace');
      return <T>[];
    }
  }

  Future<TodayOverview> _loadOverview() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime horizon = today.add(const Duration(days: 14));

    final List<AcademicSubjectV2> subjects =
        await _loadTodaySection<AcademicSubjectV2>(
          'subjects',
          _repository.fetchSubjectsV2,
        );
    final Map<String, AcademicSubjectV2> subjectsById =
        <String, AcademicSubjectV2>{
          for (final AcademicSubjectV2 subject in subjects) subject.id: subject,
        };

    final List<ClassSession> sessions = await _loadTodaySection<ClassSession>(
      'class sessions',
      _repository.fetchClassSessionsV2,
    );
    final List<AcademicEvent> events = await _loadTodaySection<AcademicEvent>(
      'academic events',
      () => _repository.fetchAcademicEventsV2(from: today, to: horizon),
    );
    final List<StudyTask> tasks = await _loadTodaySection<StudyTask>(
      'study tasks',
      _repository.fetchStudyTasksV2,
    );
    final List<GradeComponentRecord> gradeComponents =
        await _loadTodaySection<GradeComponentRecord>(
          'grade components',
          _repository.fetchGradeComponentsV2,
        );

    final List<TodayClassItem> todayClasses =
        sessions
            .where(
              (ClassSession session) =>
                  session.active && session.weekday == today.weekday,
            )
            .map((ClassSession session) {
              final AcademicSubjectV2? subject =
                  subjectsById[session.subjectId];
              if (subject == null) {
                return null;
              }
              return TodayClassItem(subject: subject, session: session);
            })
            .whereType<TodayClassItem>()
            .toList(growable: false)
          ..sort(
            (TodayClassItem a, TodayClassItem b) =>
                a.session.startsAtMinutes.compareTo(b.session.startsAtMinutes),
          );

    TodayClassItem? nextClass;
    for (final TodayClassItem item in todayClasses) {
      final DateTime startsAt = today.add(
        Duration(minutes: item.session.startsAtMinutes),
      );
      if (startsAt.isAfter(now)) {
        nextClass = item;
        break;
      }
    }

    final List<TodayEventItem> upcomingEvents =
        events
            .where((AcademicEvent event) {
              final DateTime? date = event.effectiveDate;
              return date != null &&
                  date.isAfter(now.subtract(const Duration(minutes: 1))) &&
                  event.status != AcademicEventStatus.cancelled &&
                  event.status != AcademicEventStatus.done;
            })
            .map(
              (AcademicEvent event) => TodayEventItem(
                subject: event.subjectId == null
                    ? null
                    : subjectsById[event.subjectId],
                event: event,
              ),
            )
            .toList(growable: false)
          ..sort((TodayEventItem a, TodayEventItem b) {
            final DateTime aDate = a.event.effectiveDate ?? DateTime(9999);
            final DateTime bDate = b.event.effectiveDate ?? DateTime(9999);
            return aDate.compareTo(bDate);
          });

    final List<TodayTaskItem> openTasks =
        tasks
            .where(
              (StudyTask task) =>
                  task.status != StudyTaskStatus.done &&
                  task.status != StudyTaskStatus.cancelled,
            )
            .map(
              (StudyTask task) => TodayTaskItem(
                subject: task.subjectId == null
                    ? null
                    : subjectsById[task.subjectId],
                task: task,
              ),
            )
            .toList(growable: false)
          ..sort((TodayTaskItem a, TodayTaskItem b) {
            final DateTime aDate = a.task.dueAt ?? DateTime(9999);
            final DateTime bDate = b.task.dueAt ?? DateTime(9999);
            return aDate.compareTo(bDate);
          });

    final List<TodayRiskItem> risks = gradeComponents
        .map((GradeComponentRecord component) {
          final AcademicSubjectV2? subject = subjectsById[component.subjectId];
          if (subject == null) {
            return null;
          }
          final double? grade = component.grade;
          if (grade != null && grade < component.minimumGrade) {
            return TodayRiskItem(
              subject: subject,
              component: component,
              message:
                  '${component.name}: nota ${grade.toStringAsFixed(2)} este sub minimul ${component.minimumGrade.toStringAsFixed(0)}',
              severity: TodayRiskSeverity.high,
            );
          }
          if (grade == null && component.isRequired) {
            return TodayRiskItem(
              subject: subject,
              component: component,
              message: '${component.name}: nota obligatorie lipseste',
              severity: component.isEliminatory
                  ? TodayRiskSeverity.high
                  : TodayRiskSeverity.medium,
            );
          }
          return null;
        })
        .whereType<TodayRiskItem>()
        .toList(growable: false);

    return TodayOverview(
      nextClass: nextClass,
      todayClasses: todayClasses,
      upcomingEvents: upcomingEvents.take(5).toList(growable: false),
      openTasks: openTasks.take(5).toList(growable: false),
      risks: risks.take(5).toList(growable: false),
      hasAnyData:
          subjects.isNotEmpty ||
          sessions.isNotEmpty ||
          events.isNotEmpty ||
          tasks.isNotEmpty ||
          gradeComponents.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TodayOverview>(
      future: _overviewFuture,
      builder: (BuildContext context, AsyncSnapshot<TodayOverview> snapshot) {
        return TodayScreenView(
          overview: snapshot.data,
          connectionState: snapshot.connectionState,
          hasError: snapshot.hasError,
          onRefresh: _reload,
          onRetry: _reload,
          onOpenSchedule: widget.onOpenSchedule,
          onOpenSubjects: widget.onOpenSubjects,
        );
      },
    );
  }
}
