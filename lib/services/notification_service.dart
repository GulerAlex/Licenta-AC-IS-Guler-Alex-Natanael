import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/models/exam_event.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const int _courseNotificationStart = 100000;
  static const int _courseNotificationEnd = 199999;
  static const int _examNotificationStart = 200000;
  static const int _examNotificationEnd = 299999;
  static const int _scheduleDaysAhead = 28;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) {
      return;
    }

    tz_data.initializeTimeZones();
    try {
      final TimezoneInfo timezoneInfo =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Failed to resolve device timezone: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings, iOS: darwinSettings);

    await _plugin.initialize(settings: initializationSettings);
    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      return false;
    }
    await initialize();

    final bool? androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final bool? iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return androidGranted ?? iosGranted ?? true;
  }

  // Legacy reminder API kept for backwards-compatible migration/debug paths.
  // Normal screens schedule notifications through rescheduleAcademicRemindersV2.
  Future<void> rescheduleAcademicReminders({
    required List<Course> courses,
    required List<ExamEvent> exams,
    required Set<String> hiddenScheduleSemesters,
    required bool courseNotificationsEnabled,
    required bool examNotificationsEnabled,
    required int courseReminderMinutes,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _cancelAcademicReminders();

    final DateTime now = DateTime.now();
    if (courseNotificationsEnabled) {
      await _scheduleCourseReminders(
        courses: courses,
        hiddenScheduleSemesters: hiddenScheduleSemesters,
        now: now,
        reminderMinutes: courseReminderMinutes,
      );
    }

    if (examNotificationsEnabled) {
      await _scheduleExamReminders(exams: exams, now: now);
    }
  }

  Future<void> rescheduleAcademicRemindersV2({
    required List<AcademicSubjectV2> subjects,
    required List<ClassSession> classSessions,
    required List<AcademicEvent> events,
    required Set<String> hiddenScheduleSemesters,
    required bool courseNotificationsEnabled,
    required bool examNotificationsEnabled,
    required int courseReminderMinutes,
  }) async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _cancelAcademicReminders();

    final DateTime now = DateTime.now();
    final Map<String, AcademicSubjectV2> subjectsById =
        <String, AcademicSubjectV2>{
          for (final AcademicSubjectV2 subject in subjects) subject.id: subject,
        };

    if (courseNotificationsEnabled) {
      await _scheduleClassSessionReminders(
        subjectsById: subjectsById,
        classSessions: classSessions,
        hiddenScheduleSemesters: hiddenScheduleSemesters,
        now: now,
        reminderMinutes: courseReminderMinutes,
      );
    }

    if (examNotificationsEnabled) {
      await _scheduleAcademicEventReminders(
        subjectsById: subjectsById,
        events: events,
        now: now,
      );
    }
  }

  Future<void> cancelAcademicReminders() async {
    if (kIsWeb) {
      return;
    }
    await initialize();
    await _cancelAcademicReminders();
  }

  Future<void> _cancelAcademicReminders() async {
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    for (final PendingNotificationRequest request in pending) {
      final int id = request.id;
      if ((id >= _courseNotificationStart && id <= _courseNotificationEnd) ||
          (id >= _examNotificationStart && id <= _examNotificationEnd)) {
        await _plugin.cancel(id: id);
      }
    }
  }

  Future<void> _scheduleCourseReminders({
    required List<Course> courses,
    required Set<String> hiddenScheduleSemesters,
    required DateTime now,
    required int reminderMinutes,
  }) async {
    final DateTime today = DateTime(now.year, now.month, now.day);
    int index = 0;

    for (final Course course in courses) {
      if (hiddenScheduleSemesters.contains(course.semesterLabel) ||
          course.time.trim().isEmpty) {
        continue;
      }

      final int? weekday = _weekdayFromLabel(course.weekdayLabel);
      final int? startMinutes = _startMinutesFromTimeLabel(course.time);
      if (weekday == null || startMinutes == null) {
        continue;
      }

      for (int dayOffset = 0; dayOffset < _scheduleDaysAhead; dayOffset++) {
        final DateTime day = today.add(Duration(days: dayOffset));
        if (day.weekday != weekday) {
          continue;
        }

        final DateTime courseStart = day.add(Duration(minutes: startMinutes));
        final DateTime reminderAt = courseStart.subtract(
          Duration(minutes: reminderMinutes),
        );
        if (!reminderAt.isAfter(now)) {
          continue;
        }

        await _schedule(
          id: _courseNotificationStart + index,
          title: '${course.courseType} in curand',
          body:
              '${course.name} incepe la ${_formatTime(courseStart)}'
              '${course.room.trim().isEmpty ? '' : ' in ${course.room.trim()}'}',
          scheduledAt: reminderAt,
          payload: 'course:${course.name}',
        );
        index += 1;
        if (_courseNotificationStart + index > _courseNotificationEnd) {
          return;
        }
      }
    }
  }

  Future<void> _scheduleExamReminders({
    required List<ExamEvent> exams,
    required DateTime now,
  }) async {
    int index = 0;
    for (final ExamEvent exam in exams) {
      if (!exam.notificationsEnabled || !exam.startsAt.isAfter(now)) {
        continue;
      }

      final DateTime reminderAt = exam.startsAt.subtract(
        Duration(minutes: exam.reminderMinutesBefore),
      );
      if (!reminderAt.isAfter(now)) {
        continue;
      }

      await _schedule(
        id: _examNotificationStart + index,
        title: '${exam.examType} in curand',
        body:
            '${exam.subjectName} incepe la ${_formatTime(exam.startsAt)}'
            '${exam.room.trim().isEmpty ? '' : ' in ${exam.room.trim()}'}',
        scheduledAt: reminderAt,
        payload: 'exam:${exam.id}',
      );
      index += 1;
      if (_examNotificationStart + index > _examNotificationEnd) {
        return;
      }
    }
  }

  Future<void> _scheduleClassSessionReminders({
    required Map<String, AcademicSubjectV2> subjectsById,
    required List<ClassSession> classSessions,
    required Set<String> hiddenScheduleSemesters,
    required DateTime now,
    required int reminderMinutes,
  }) async {
    final DateTime today = DateTime(now.year, now.month, now.day);
    int index = 0;

    for (final ClassSession session in classSessions) {
      if (!session.active) {
        continue;
      }
      final AcademicSubjectV2? subject = subjectsById[session.subjectId];
      if (subject == null ||
          subject.archived ||
          hiddenScheduleSemesters.contains(subject.semesterLabel)) {
        continue;
      }

      for (int dayOffset = 0; dayOffset < _scheduleDaysAhead; dayOffset++) {
        final DateTime day = today.add(Duration(days: dayOffset));
        if (day.weekday != session.weekday) {
          continue;
        }

        final DateTime sessionStart = day.add(
          Duration(minutes: session.startsAtMinutes),
        );
        final DateTime reminderAt = sessionStart.subtract(
          Duration(minutes: reminderMinutes),
        );
        if (!reminderAt.isAfter(now)) {
          continue;
        }

        await _schedule(
          id: _courseNotificationStart + index,
          title: '${session.sessionType} in curand',
          body:
              '${subject.name} incepe la ${_formatTime(sessionStart)}'
              '${session.room.trim().isEmpty ? '' : ' in ${session.room.trim()}'}',
          scheduledAt: reminderAt,
          payload: 'class_session:${session.id}',
        );
        index += 1;
        if (_courseNotificationStart + index > _courseNotificationEnd) {
          return;
        }
      }
    }
  }

  Future<void> _scheduleAcademicEventReminders({
    required Map<String, AcademicSubjectV2> subjectsById,
    required List<AcademicEvent> events,
    required DateTime now,
  }) async {
    int index = 0;
    for (final AcademicEvent event in events) {
      final DateTime? eventDate = event.startsAt ?? event.dueAt;
      if (!event.notificationsEnabled ||
          eventDate == null ||
          !eventDate.isAfter(now) ||
          !_isExamLikeEvent(event.type)) {
        continue;
      }

      final DateTime reminderAt = eventDate.subtract(
        Duration(minutes: event.reminderMinutesBefore),
      );
      if (!reminderAt.isAfter(now)) {
        continue;
      }

      final String subjectName = event.subjectId == null
          ? event.title
          : subjectsById[event.subjectId]?.name ?? event.title;

      await _schedule(
        id: _examNotificationStart + index,
        title: '${event.type.label} in curand',
        body:
            '$subjectName incepe la ${_formatTime(eventDate)}'
            '${event.room.trim().isEmpty ? '' : ' in ${event.room.trim()}'}',
        scheduledAt: reminderAt,
        payload: 'academic_event:${event.id}',
      );
      index += 1;
      if (_examNotificationStart + index > _examNotificationEnd) {
        return;
      }
    }
  }

  bool _isExamLikeEvent(AcademicEventType type) {
    return switch (type) {
      AcademicEventType.exam ||
      AcademicEventType.colloquium ||
      AcademicEventType.retake ||
      AcademicEventType.project => true,
      _ => false,
    };
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'academic_reminders',
        'Reminder-e academice',
        channelDescription: 'Notificari pentru cursuri, seminare si examene.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
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

  int? _startMinutesFromTimeLabel(String value) {
    final RegExpMatch? match = RegExp(
      r'(\d{1,2})\s*:\s*(\d{2})',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }

    final int? hour = int.tryParse(match.group(1) ?? '');
    final int? minute = int.tryParse(match.group(2) ?? '');
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return (hour * 60) + minute;
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
