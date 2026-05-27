import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_progress.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/models/exam_event.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/models/profile_stats.dart';
import 'package:unihub/models/study_task.dart';
import 'package:unihub/models/user_profile.dart';
import 'package:unihub/services/academic_progress_calculator.dart';

class UniHubRepository {
  UniHubRepository._();

  static final UniHubRepository instance = UniHubRepository._();
  final ValueNotifier<int> coursesVersion = ValueNotifier<int>(0);
  static const String pendingCourseTimeLabel = '__PENDING__';
  static const List<String> availableGroups = <String>[
    '1.1',
    '1.2',
    '2.1',
    '2.2',
    '3.1',
    '3.2',
  ];
  static const List<String> availableSemesters = <String>[
    'Semestrul 1',
    'Semestrul 2',
  ];

  SupabaseClient get _client => Supabase.instance.client;

  void _notifyCoursesChanged() {
    coursesVersion.value += 1;
  }

  // Legacy academic API kept only for one-time migration from the old schema.
  // New app flows should use subjects/class_sessions/academic_events/grade_components.
  Future<List<Course>> fetchCourses({required String semesterLabel}) async {
    if (!availableSemesters.contains(semesterLabel)) {
      throw ArgumentError.value(
        semesterLabel,
        'semesterLabel',
        'Invalid semester label',
      );
    }

    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> rows = await _client
        .from('courses')
        .select(
          'name, semester_label, credits, course_type, weekday_label, time_label, room, professor, sort_order',
        )
        .eq('user_id', user.id)
        .eq('semester_label', semesterLabel)
        .order('weekday_label', ascending: true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return rows
        .map((dynamic row) => Course.fromMap(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Course>> fetchUserCourses() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> rows = await _client
        .from('courses')
        .select(
          'name, semester_label, credits, course_type, weekday_label, time_label, room, professor, sort_order',
        )
        .eq('user_id', user.id)
        .order('weekday_label', ascending: true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return rows
        .map((dynamic row) => Course.fromMap(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> addUserCourse(Course course) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('courses').insert(<String, dynamic>{
      'user_id': user.id,
      'name': course.name,
      'semester_label': course.semesterLabel,
      'credits': course.credits,
      'course_type': course.courseType,
      'weekday_label': course.weekdayLabel,
      'time_label': course.time,
      'room': course.room,
      'professor': course.professor,
      'sort_order': course.sortOrder,
    });
    _notifyCoursesChanged();
  }

  Future<void> addCourseSubject({
    required String subjectName,
    required String semesterLabel,
    required int credits,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedSubjectName = subjectName.trim();
    if (normalizedSubjectName.isEmpty) {
      throw ArgumentError.value(
        subjectName,
        'subjectName',
        'Subject name cannot be empty',
      );
    }

    if (!availableSemesters.contains(semesterLabel)) {
      throw ArgumentError.value(
        semesterLabel,
        'semesterLabel',
        'Invalid semester label',
      );
    }

    if (credits <= 0 || credits > 60) {
      throw ArgumentError.value(credits, 'credits', 'Invalid credits value');
    }

    await _client.from('courses').insert(<String, dynamic>{
      'user_id': user.id,
      'name': normalizedSubjectName,
      'semester_label': semesterLabel,
      'credits': credits,
      'course_type': 'Curs',
      'weekday_label': 'Luni',
      'time_label': pendingCourseTimeLabel,
      'room': '-',
      'professor': '-',
      'sort_order': 9999,
    });
    _notifyCoursesChanged();
  }

  Future<void> clearPendingCourseDraft({
    required String subjectName,
    required String semesterLabel,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client
        .from('courses')
        .delete()
        .eq('user_id', user.id)
        .eq('semester_label', semesterLabel)
        .eq('name', subjectName)
        .eq('time_label', pendingCourseTimeLabel);
    _notifyCoursesChanged();
  }

  Future<int> deleteSubjectCourses({
    required String subjectName,
    required String semesterLabel,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> deletedRows = await _client
        .from('courses')
        .delete()
        .eq('user_id', user.id)
        .eq('semester_label', semesterLabel)
        .eq('name', subjectName)
        .select('id');

    if (deletedRows.isNotEmpty) {
      _notifyCoursesChanged();
    }
    return deletedRows.length;
  }

  Future<int> deleteCourseTypeEntry({required Course course}) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> deletedRows = await _client
        .from('courses')
        .delete()
        .eq('user_id', user.id)
        .eq('semester_label', course.semesterLabel)
        .eq('name', course.name)
        .eq('course_type', course.courseType)
        .eq('time_label', course.time)
        .eq('room', course.room)
        .select('id');

    if (deletedRows.isNotEmpty) {
      _notifyCoursesChanged();
    }
    return deletedRows.length;
  }

  Future<int> updateCourseTypeEntry({
    required Course originalCourse,
    required Course updatedCourse,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> updatedRows = await _client
        .from('courses')
        .update(<String, dynamic>{
          'credits': updatedCourse.credits,
          'course_type': updatedCourse.courseType,
          'weekday_label': updatedCourse.weekdayLabel,
          'time_label': updatedCourse.time,
          'room': updatedCourse.room,
          'professor': updatedCourse.professor,
          'sort_order': updatedCourse.sortOrder,
        })
        .eq('user_id', user.id)
        .eq('semester_label', originalCourse.semesterLabel)
        .eq('name', originalCourse.name)
        .eq('course_type', originalCourse.courseType)
        .eq('time_label', originalCourse.time)
        .eq('room', originalCourse.room)
        .select('id');

    if (updatedRows.isNotEmpty) {
      _notifyCoursesChanged();
    }
    return updatedRows.length;
  }

  Future<void> clearUserCourses() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('courses').delete().eq('user_id', user.id);
    _notifyCoursesChanged();
  }

  Future<void> replaceUserCourses(List<Course> courses) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('courses').delete().eq('user_id', user.id);

    if (courses.isEmpty) {
      _notifyCoursesChanged();
      return;
    }

    final List<Map<String, dynamic>> payload = courses
        .map(
          (Course course) => <String, dynamic>{
            'user_id': user.id,
            'name': course.name,
            'semester_label': course.semesterLabel,
            'credits': course.credits,
            'course_type': course.courseType,
            'weekday_label': course.weekdayLabel,
            'time_label': course.time,
            'room': course.room,
            'professor': course.professor,
            'sort_order': course.sortOrder,
          },
        )
        .toList(growable: false);

    await _client.from('courses').insert(payload);
    _notifyCoursesChanged();
  }

  Future<Map<String, double>> fetchGradeTypeWeights() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> rows = await _client
        .from('grade_type_weights')
        .select('subject_name, course_type, weight_percent')
        .eq('user_id', user.id);

    final Map<String, double> weights = <String, double>{};
    for (final dynamic row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final String subjectName = (row['subject_name'] as String?)?.trim() ?? '';
      final String courseType = (row['course_type'] as String?)?.trim() ?? '';
      if (subjectName.isEmpty || courseType.isEmpty) {
        continue;
      }

      final dynamic weightRaw = row['weight_percent'];
      final double? weight = switch (weightRaw) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      };

      if (weight == null || weight < 0 || weight > 100) {
        continue;
      }

      weights['$subjectName|$courseType'] = weight;
    }

    return weights;
  }

  Future<Map<String, double>> fetchGradeTypeGrades() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> rows = await _client
        .from('grade_type_grades')
        .select('subject_name, course_type, score')
        .eq('user_id', user.id);

    final Map<String, double> grades = <String, double>{};
    for (final dynamic row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final String subjectName = (row['subject_name'] as String?)?.trim() ?? '';
      final String courseType = (row['course_type'] as String?)?.trim() ?? '';
      if (subjectName.isEmpty || courseType.isEmpty) {
        continue;
      }

      final dynamic scoreRaw = row['score'];
      final double? score = switch (scoreRaw) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      };

      if (score == null || score < 1 || score > 10) {
        continue;
      }

      grades['$subjectName|$courseType'] = score;
    }

    return grades;
  }

  Future<void> setGradeTypeGrade({
    required String subjectName,
    required String courseType,
    required double? score,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedSubject = subjectName.trim();
    final String normalizedType = courseType.trim();
    if (normalizedSubject.isEmpty || normalizedType.isEmpty) {
      throw ArgumentError('Subject name and course type are required.');
    }

    if (score == null) {
      await _client
          .from('grade_type_grades')
          .delete()
          .eq('user_id', user.id)
          .eq('subject_name', normalizedSubject)
          .eq('course_type', normalizedType);
      return;
    }

    await _client.from('grade_type_grades').upsert(<String, dynamic>{
      'user_id': user.id,
      'subject_name': normalizedSubject,
      'course_type': normalizedType,
      'score': score,
    }, onConflict: 'user_id,subject_name,course_type');
  }

  Future<void> upsertGradeTypeGrades(List<Map<String, dynamic>> items) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    if (items.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> item in items) {
      final String subjectName =
          (item['subject_name'] as String?)?.trim() ?? '';
      final String courseType = (item['course_type'] as String?)?.trim() ?? '';
      final double? score = switch (item['score']) {
        num value => value.toDouble(),
        String value => double.tryParse(value),
        _ => null,
      };

      if (subjectName.isEmpty || courseType.isEmpty) {
        continue;
      }

      if (score == null || score < 1 || score > 10) {
        continue;
      }

      payload.add(<String, dynamic>{
        'user_id': user.id,
        'subject_name': subjectName,
        'course_type': courseType,
        'score': score,
      });
    }

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from('grade_type_grades')
        .upsert(payload, onConflict: 'user_id,subject_name,course_type');
  }

  Future<void> setGradeTypeWeights({
    required String subjectName,
    required Map<String, double> weightsByType,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedSubject = subjectName.trim();
    if (normalizedSubject.isEmpty) {
      throw ArgumentError.value(
        subjectName,
        'subjectName',
        'Subject name cannot be empty',
      );
    }

    await _client
        .from('grade_type_weights')
        .delete()
        .eq('user_id', user.id)
        .eq('subject_name', normalizedSubject);

    if (weightsByType.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> payload = weightsByType.entries
        .where((MapEntry<String, double> entry) => entry.value > 0)
        .map(
          (MapEntry<String, double> entry) => <String, dynamic>{
            'user_id': user.id,
            'subject_name': normalizedSubject,
            'course_type': entry.key,
            'weight_percent': entry.value,
          },
        )
        .toList(growable: false);

    if (payload.isEmpty) {
      return;
    }

    await _client.from('grade_type_weights').insert(payload);
  }

  Future<Map<String, String>> fetchResourceNotes() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> rows = await _client
        .from('resource_notes')
        .select('note_date, note_text')
        .eq('user_id', user.id);

    final Map<String, String> notes = <String, String>{};
    for (final dynamic row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final dynamic dateRaw = row['note_date'];
      final String dateKey = switch (dateRaw) {
        DateTime value =>
          '${value.year.toString().padLeft(4, '0')}'
              '-${value.month.toString().padLeft(2, '0')}'
              '-${value.day.toString().padLeft(2, '0')}',
        String value => value.trim(),
        _ => '',
      };

      final String noteText = (row['note_text'] as String?)?.trim() ?? '';
      if (dateKey.isEmpty || noteText.isEmpty) {
        continue;
      }

      notes[dateKey] = noteText;
    }

    return notes;
  }

  Future<void> setResourceNote({
    required String dateKey,
    required String noteText,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedDate = dateKey.trim();
    final String normalizedNote = noteText.trim();
    if (normalizedDate.isEmpty) {
      throw ArgumentError('dateKey is required.');
    }

    if (normalizedNote.isEmpty) {
      await _client
          .from('resource_notes')
          .delete()
          .eq('user_id', user.id)
          .eq('note_date', normalizedDate);
      return;
    }

    await _client.from('resource_notes').upsert(<String, dynamic>{
      'user_id': user.id,
      'note_date': normalizedDate,
      'note_text': normalizedNote,
    }, onConflict: 'user_id,note_date');
  }

  Future<void> deleteResourceNote({required String dateKey}) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedDate = dateKey.trim();
    if (normalizedDate.isEmpty) {
      throw ArgumentError('dateKey is required.');
    }

    await _client
        .from('resource_notes')
        .delete()
        .eq('user_id', user.id)
        .eq('note_date', normalizedDate);
  }

  Future<void> upsertResourceNotes(Map<String, String> notesByDay) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    if (notesByDay.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
    notesByDay.forEach((String key, String value) {
      final String normalizedKey = key.trim();
      final String normalizedValue = value.trim();
      if (normalizedKey.isEmpty || normalizedValue.isEmpty) {
        return;
      }

      payload.add(<String, dynamic>{
        'user_id': user.id,
        'note_date': normalizedKey,
        'note_text': normalizedValue,
      });
    });

    if (payload.isEmpty) {
      return;
    }

    await _client
        .from('resource_notes')
        .upsert(payload, onConflict: 'user_id,note_date');
  }

  Future<List<ExamEvent>> fetchExamEvents() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> rows = await _client
        .from('exam_events')
        .select(
          'id, subject_name, exam_type, starts_at, room, notes, reminder_minutes_before, notifications_enabled',
        )
        .eq('user_id', user.id)
        .order('starts_at', ascending: true);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ExamEvent.fromMap)
        .toList(growable: false);
  }

  Future<ExamEvent> addExamEvent(ExamEvent event) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    _validateExamEvent(event);

    final List<dynamic> rows = await _client
        .from('exam_events')
        .insert(event.toSupabasePayload(userId: user.id))
        .select(
          'id, subject_name, exam_type, starts_at, room, notes, reminder_minutes_before, notifications_enabled',
        );

    return ExamEvent.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<ExamEvent> updateExamEvent(ExamEvent event) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    if (event.id.trim().isEmpty) {
      throw ArgumentError('Exam id is required.');
    }
    _validateExamEvent(event);

    final List<dynamic> rows = await _client
        .from('exam_events')
        .update(event.toSupabasePayload(userId: user.id))
        .eq('user_id', user.id)
        .eq('id', event.id)
        .select(
          'id, subject_name, exam_type, starts_at, room, notes, reminder_minutes_before, notifications_enabled',
        );

    if (rows.isEmpty) {
      throw StateError('Exam event not found.');
    }

    return ExamEvent.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> deleteExamEvent(String examEventId) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedId = examEventId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('examEventId is required.');
    }

    await _client
        .from('exam_events')
        .delete()
        .eq('user_id', user.id)
        .eq('id', normalizedId);
  }

  void _validateExamEvent(ExamEvent event) {
    if (event.subjectName.trim().isEmpty) {
      throw ArgumentError('Subject name is required.');
    }
    if (event.examType.trim().isEmpty) {
      throw ArgumentError('Exam type is required.');
    }
    if (event.reminderMinutesBefore < 0) {
      throw ArgumentError('Reminder cannot be negative.');
    }
  }

  Future<List<AcademicSubjectV2>> fetchSubjectsV2({
    bool includeArchived = false,
  }) async {
    final User user = _requireCurrentUser();
    var query = _client
        .from('subjects')
        .select(
          'id, name, semester_label, credits, professor, color_hex, archived',
        )
        .eq('user_id', user.id);
    if (!includeArchived) {
      query = query.eq('archived', false);
    }

    final List<dynamic> rows = await query
        .order('semester_label', ascending: true)
        .order('name', ascending: true);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(AcademicSubjectV2.fromMap)
        .toList(growable: false);
  }

  Future<AcademicSubjectV2> upsertSubjectV2(AcademicSubjectV2 subject) async {
    final User user = _requireCurrentUser();
    _validateSubjectV2(subject);

    final Map<String, dynamic> payload = subject.toSupabasePayload(
      userId: user.id,
    );

    final List<dynamic> rows;
    if (subject.id.trim().isEmpty) {
      rows = await _client
          .from('subjects')
          .upsert(payload, onConflict: 'user_id,name,semester_label')
          .select(
            'id, name, semester_label, credits, professor, color_hex, archived',
          );
    } else {
      rows = await _client
          .from('subjects')
          .update(payload)
          .eq('user_id', user.id)
          .eq('id', subject.id)
          .select(
            'id, name, semester_label, credits, professor, color_hex, archived',
          );
    }

    if (rows.isEmpty) {
      throw StateError('Subject not found.');
    }
    return AcademicSubjectV2.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> deleteSubjectV2(String subjectId) async {
    final User user = _requireCurrentUser();
    final String normalizedId = subjectId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('subjectId is required.');
    }

    await _client
        .from('subjects')
        .delete()
        .eq('user_id', user.id)
        .eq('id', normalizedId);
  }

  Future<List<ClassSession>> fetchClassSessionsV2({String? subjectId}) async {
    final User user = _requireCurrentUser();
    var query = _client
        .from('class_sessions')
        .select(
          'id, subject_id, session_type, weekday, starts_at_time, ends_at_time, room, professor, active',
        )
        .eq('user_id', user.id);
    final String normalizedSubjectId = subjectId?.trim() ?? '';
    if (normalizedSubjectId.isNotEmpty) {
      query = query.eq('subject_id', normalizedSubjectId);
    }

    final List<dynamic> rows = await query
        .order('weekday', ascending: true)
        .order('starts_at_time', ascending: true);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ClassSession.fromMap)
        .toList(growable: false);
  }

  Future<ClassSession> upsertClassSessionV2(ClassSession session) async {
    final User user = _requireCurrentUser();
    _validateClassSession(session);
    final Map<String, dynamic> payload = session.toSupabasePayload(
      userId: user.id,
    );

    final List<dynamic> rows;
    if (session.id.trim().isEmpty) {
      rows = await _client
          .from('class_sessions')
          .insert(payload)
          .select(
            'id, subject_id, session_type, weekday, starts_at_time, ends_at_time, room, professor, active',
          );
    } else {
      rows = await _client
          .from('class_sessions')
          .update(payload)
          .eq('user_id', user.id)
          .eq('id', session.id)
          .select(
            'id, subject_id, session_type, weekday, starts_at_time, ends_at_time, room, professor, active',
          );
    }

    if (rows.isEmpty) {
      throw StateError('Class session not found.');
    }
    return ClassSession.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> deleteClassSessionV2(String classSessionId) async {
    final User user = _requireCurrentUser();
    final String normalizedId = classSessionId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('classSessionId is required.');
    }

    await _client
        .from('class_sessions')
        .delete()
        .eq('user_id', user.id)
        .eq('id', normalizedId);
  }

  Future<List<AcademicEvent>> fetchAcademicEventsV2({
    DateTime? from,
    DateTime? to,
    String? subjectId,
  }) async {
    final User user = _requireCurrentUser();
    var query = _client
        .from('academic_events')
        .select(
          'id, subject_id, event_type, title, starts_at, due_at, room, notes, priority, status, reminder_minutes_before, notifications_enabled',
        )
        .eq('user_id', user.id);

    final String normalizedSubjectId = subjectId?.trim() ?? '';
    if (normalizedSubjectId.isNotEmpty) {
      query = query.eq('subject_id', normalizedSubjectId);
    }
    if (from != null) {
      query = query.or(
        'starts_at.gte.${from.toUtc().toIso8601String()},due_at.gte.${from.toUtc().toIso8601String()}',
      );
    }
    if (to != null) {
      query = query.or(
        'starts_at.lte.${to.toUtc().toIso8601String()},due_at.lte.${to.toUtc().toIso8601String()}',
      );
    }

    final List<dynamic> rows = await query.order('due_at', ascending: true);
    final List<AcademicEvent> events = rows
        .whereType<Map<String, dynamic>>()
        .map(AcademicEvent.fromMap)
        .toList(growable: false);
    events.sort((AcademicEvent a, AcademicEvent b) {
      final DateTime aDate = a.effectiveDate ?? DateTime(9999);
      final DateTime bDate = b.effectiveDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return events;
  }

  Future<AcademicEvent> upsertAcademicEventV2(AcademicEvent event) async {
    final User user = _requireCurrentUser();
    _validateAcademicEvent(event);
    final Map<String, dynamic> payload = event.toSupabasePayload(
      userId: user.id,
    );

    final List<dynamic> rows;
    if (event.id.trim().isEmpty) {
      rows = await _client
          .from('academic_events')
          .insert(payload)
          .select(
            'id, subject_id, event_type, title, starts_at, due_at, room, notes, priority, status, reminder_minutes_before, notifications_enabled',
          );
    } else {
      rows = await _client
          .from('academic_events')
          .update(payload)
          .eq('user_id', user.id)
          .eq('id', event.id)
          .select(
            'id, subject_id, event_type, title, starts_at, due_at, room, notes, priority, status, reminder_minutes_before, notifications_enabled',
          );
    }

    if (rows.isEmpty) {
      throw StateError('Academic event not found.');
    }
    return AcademicEvent.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> deleteAcademicEventV2(String academicEventId) async {
    final User user = _requireCurrentUser();
    final String normalizedId = academicEventId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('academicEventId is required.');
    }

    await _client
        .from('academic_events')
        .delete()
        .eq('user_id', user.id)
        .eq('id', normalizedId);
  }

  Future<List<GradeComponentRecord>> fetchGradeComponentsV2({
    String? subjectId,
  }) async {
    final User user = _requireCurrentUser();
    var query = _client
        .from('grade_components')
        .select(
          'id, subject_id, name, component_type, weight_percent, minimum_grade, grade, is_required, is_eliminatory',
        )
        .eq('user_id', user.id);
    final String normalizedSubjectId = subjectId?.trim() ?? '';
    if (normalizedSubjectId.isNotEmpty) {
      query = query.eq('subject_id', normalizedSubjectId);
    }

    final List<dynamic> rows = await query.order('name', ascending: true);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(GradeComponentRecord.fromMap)
        .toList(growable: false);
  }

  Future<GradeComponentRecord> upsertGradeComponentV2(
    GradeComponentRecord component,
  ) async {
    final User user = _requireCurrentUser();
    _validateGradeComponent(component);
    final Map<String, dynamic> payload = component.toSupabasePayload(
      userId: user.id,
    );

    final List<dynamic> rows;
    if (component.id.trim().isEmpty) {
      rows = await _client
          .from('grade_components')
          .insert(payload)
          .select(
            'id, subject_id, name, component_type, weight_percent, minimum_grade, grade, is_required, is_eliminatory',
          );
    } else {
      rows = await _client
          .from('grade_components')
          .update(payload)
          .eq('user_id', user.id)
          .eq('id', component.id)
          .select(
            'id, subject_id, name, component_type, weight_percent, minimum_grade, grade, is_required, is_eliminatory',
          );
    }

    if (rows.isEmpty) {
      throw StateError('Grade component not found.');
    }
    return GradeComponentRecord.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<List<StudyTask>> fetchStudyTasksV2({
    bool includeDone = false,
    String? subjectId,
  }) async {
    final User user = _requireCurrentUser();
    var query = _client
        .from('study_tasks')
        .select(
          'id, subject_id, academic_event_id, title, due_at, estimated_minutes, priority, status, reminder_minutes_before, notifications_enabled',
        )
        .eq('user_id', user.id);
    final String normalizedSubjectId = subjectId?.trim() ?? '';
    if (normalizedSubjectId.isNotEmpty) {
      query = query.eq('subject_id', normalizedSubjectId);
    }
    if (!includeDone) {
      query = query.neq('status', 'done');
    }

    final List<dynamic> rows = await query.order('due_at', ascending: true);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(StudyTask.fromMap)
        .toList(growable: false);
  }

  Future<StudyTask> upsertStudyTaskV2(StudyTask task) async {
    final User user = _requireCurrentUser();
    _validateStudyTask(task);
    final Map<String, dynamic> payload = task.toSupabasePayload(
      userId: user.id,
    );

    final List<dynamic> rows;
    if (task.id.trim().isEmpty) {
      rows = await _client
          .from('study_tasks')
          .insert(payload)
          .select(
            'id, subject_id, academic_event_id, title, due_at, estimated_minutes, priority, status, reminder_minutes_before, notifications_enabled',
          );
    } else {
      rows = await _client
          .from('study_tasks')
          .update(payload)
          .eq('user_id', user.id)
          .eq('id', task.id)
          .select(
            'id, subject_id, academic_event_id, title, due_at, estimated_minutes, priority, status, reminder_minutes_before, notifications_enabled',
          );
    }

    if (rows.isEmpty) {
      throw StateError('Study task not found.');
    }
    return StudyTask.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<void> deleteStudyTaskV2(String studyTaskId) async {
    final User user = _requireCurrentUser();
    final String normalizedId = studyTaskId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('studyTaskId is required.');
    }

    await _client
        .from('study_tasks')
        .delete()
        .eq('user_id', user.id)
        .eq('id', normalizedId);
  }

  User _requireCurrentUser() {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user;
  }

  void _validateSubjectV2(AcademicSubjectV2 subject) {
    if (subject.name.trim().isEmpty) {
      throw ArgumentError('Subject name is required.');
    }
    if (subject.semesterLabel.trim().isEmpty) {
      throw ArgumentError('Semester label is required.');
    }
    if (subject.credits <= 0 || subject.credits > 60) {
      throw ArgumentError('Credits must be between 1 and 60.');
    }
  }

  void _validateClassSession(ClassSession session) {
    if (session.subjectId.trim().isEmpty) {
      throw ArgumentError('subjectId is required.');
    }
    if (!const <String>{
      'Curs',
      'Seminar',
      'Laborator',
    }.contains(session.sessionType.trim())) {
      throw ArgumentError('Invalid session type.');
    }
    if (session.endsAtMinutes <= session.startsAtMinutes) {
      throw ArgumentError('Class session end must be after start.');
    }
  }

  void _validateAcademicEvent(AcademicEvent event) {
    if (event.title.trim().isEmpty) {
      throw ArgumentError('Event title is required.');
    }
    if (event.startsAt == null && event.dueAt == null) {
      throw ArgumentError('Event must have startsAt or dueAt.');
    }
    if (event.reminderMinutesBefore < 0) {
      throw ArgumentError('Reminder cannot be negative.');
    }
  }

  void _validateGradeComponent(GradeComponentRecord component) {
    if (component.subjectId.trim().isEmpty) {
      throw ArgumentError('subjectId is required.');
    }
    if (component.name.trim().isEmpty) {
      throw ArgumentError('Component name is required.');
    }
    if (component.weightPercent < 0 || component.weightPercent > 100) {
      throw ArgumentError('Weight must be between 0 and 100.');
    }
  }

  void _validateStudyTask(StudyTask task) {
    if (task.title.trim().isEmpty) {
      throw ArgumentError('Task title is required.');
    }
    final int? estimatedMinutes = task.estimatedMinutes;
    if (estimatedMinutes != null && estimatedMinutes <= 0) {
      throw ArgumentError('Estimated minutes must be positive.');
    }
  }

  Future<String?> fetchCurrentGroupCode() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select('group_code')
        .eq('id', user.id)
        .maybeSingle();

    final String groupCode = (row?['group_code'] as String?)?.trim() ?? '';
    if (groupCode.isEmpty) {
      return null;
    }
    return groupCode;
  }

  Future<void> setCurrentGroupCode(String groupCode) async {
    if (!availableGroups.contains(groupCode)) {
      throw ArgumentError.value(groupCode, 'groupCode', 'Invalid group code');
    }

    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client
        .from('profiles')
        .update(<String, dynamic>{'group_code': groupCode})
        .eq('id', user.id);
  }

  Future<void> setAcademicProfileDetails({
    required String faculty,
    required int studyYear,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedFaculty = faculty.trim();
    if (normalizedFaculty.isEmpty) {
      throw ArgumentError('faculty is required.');
    }
    if (studyYear < 1 || studyYear > 4) {
      throw ArgumentError('studyYear must be between 1 and 4.');
    }

    await _client.from('profiles').upsert(<String, dynamic>{
      'id': user.id,
      'faculty': normalizedFaculty,
      'study_year': studyYear,
    }, onConflict: 'id');
  }

  Future<UserProfile> fetchProfile() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select('full_name, faculty, study_year, university_email, group_code')
        .eq('id', user.id)
        .maybeSingle();

    final String fallbackName =
        (user.userMetadata?['name'] as String?)?.trim() ?? 'Student';

    return UserProfile.fromSupabase(
      row: row,
      fallbackEmail: user.email ?? '',
      fallbackName: fallbackName,
    );
  }

  Future<void> updateProfile({
    required String fullName,
    required String faculty,
    required int? studyYear,
    required String universityEmail,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final String normalizedName = fullName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('fullName is required.');
    }

    final String normalizedFaculty = faculty.trim();
    final String normalizedEmail = universityEmail.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('universityEmail is invalid.');
    }

    final int? normalizedStudyYear = (studyYear != null && studyYear > 0)
        ? studyYear
        : null;

    await _client
        .from('profiles')
        .update(<String, dynamic>{
          'full_name': normalizedName,
          'faculty': normalizedFaculty,
          'study_year': normalizedStudyYear,
          'university_email': normalizedEmail,
        })
        .eq('id', user.id);
  }

  Future<ProfileStats> fetchProfileStats({String? semesterLabel}) async {
    final List<AcademicSubjectV2> subjectRows = await fetchSubjectsV2();
    final List<ClassSession> sessions = await fetchClassSessionsV2();
    final List<GradeComponentRecord> gradeComponents =
        await fetchGradeComponentsV2();

    final List<AcademicSubject> subjects = subjectRows
        .where(
          (AcademicSubjectV2 subject) =>
              semesterLabel == null || subject.semesterLabel == semesterLabel,
        )
        .map((AcademicSubjectV2 subject) {
          final List<GradeComponentRecord> components = _profileComponentsFor(
            subject: subject,
            sessions: sessions,
            gradeComponents: gradeComponents,
          );
          final bool hasConfiguredWeights = components.any(
            (GradeComponentRecord component) => component.weightPercent > 0,
          );
          final double defaultWeight = components.isEmpty
              ? 0
              : 1 / components.length;

          return AcademicSubject(
            id: subject.id,
            name: subject.name,
            semester: subject.semesterLabel,
            year: 0,
            credits: subject.credits,
            components: components
                .map(
                  (GradeComponentRecord component) => GradeComponent(
                    id: component.id.isEmpty
                        ? '${subject.id}|${component.name}'
                        : component.id,
                    name: component.name,
                    type: _componentTypeFromRecord(component.type),
                    grade: component.grade,
                    weight: hasConfiguredWeights
                        ? component.weightPercent / 100
                        : defaultWeight,
                    minGrade: component.minimumGrade,
                    isRequired: component.isRequired,
                    isEliminatory: component.isEliminatory,
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    final AcademicProgress progress =
        AcademicProgressCalculator.calculateAcademicProgress(subjects);
    final int promotedSubjects = progress.subjects
        .where((SubjectEvaluation evaluation) => evaluation.isPromoted)
        .length;
    final int failedSubjects = progress.subjects
        .where(
          (SubjectEvaluation evaluation) =>
              evaluation.status == SubjectStatus.failed,
        )
        .length;
    final int incompleteSubjects = progress.subjects
        .where(
          (SubjectEvaluation evaluation) =>
              evaluation.status == SubjectStatus.incomplete,
        )
        .length;
    final int notStartedSubjects = progress.subjects
        .where(
          (SubjectEvaluation evaluation) =>
              evaluation.status == SubjectStatus.notStarted,
        )
        .length;

    return ProfileStats(
      totalSubjects: subjects.length,
      promotedSubjects: promotedSubjects,
      failedSubjects: failedSubjects,
      incompleteSubjects: incompleteSubjects,
      notStartedSubjects: notStartedSubjects,
      totalCredits: progress.totalPossibleCredits,
      earnedCredits: progress.totalEarnedCredits,
      failedCredits: progress.failedCredits,
      incompleteCredits: progress.incompleteCredits,
      remainingCredits: progress.remainingCredits,
      standingLabel: _standingLabel(progress.standing),
      overallAverage: progress.officialAverage,
      estimatedAverage: progress.estimatedAverage,
    );
  }

  List<GradeComponentRecord> _profileComponentsFor({
    required AcademicSubjectV2 subject,
    required List<ClassSession> sessions,
    required List<GradeComponentRecord> gradeComponents,
  }) {
    final Map<String, GradeComponentRecord> byName =
        <String, GradeComponentRecord>{
          for (final GradeComponentRecord component in gradeComponents.where(
            (GradeComponentRecord component) =>
                component.subjectId == subject.id,
          ))
            component.name: component,
        };
    byName.putIfAbsent(
      'Examen',
      () => _defaultProfileComponent(
        subjectId: subject.id,
        componentName: 'Examen',
      ),
    );
    for (final ClassSession session in sessions.where(
      (ClassSession session) => session.subjectId == subject.id,
    )) {
      final String componentName = _canonicalComponentName(session.sessionType);
      if (componentName.isEmpty || componentName == 'Alta componenta') {
        continue;
      }
      byName.putIfAbsent(
        componentName,
        () => _defaultProfileComponent(
          subjectId: subject.id,
          componentName: componentName,
        ),
      );
    }
    return byName.values.toList(growable: false);
  }

  GradeComponentRecord _defaultProfileComponent({
    required String subjectId,
    required String componentName,
  }) {
    return GradeComponentRecord(
      id: '',
      subjectId: subjectId,
      name: componentName,
      type: _componentRecordTypeFromLabel(componentName),
      weightPercent: 0,
      minimumGrade: 5,
      grade: null,
      isRequired: true,
      isEliminatory: _isEliminatoryComponent(componentName),
    );
  }

  GradeComponentType _componentTypeFromRecord(GradeComponentRecordType type) {
    return switch (type) {
      GradeComponentRecordType.exam => GradeComponentType.exam,
      GradeComponentRecordType.seminar => GradeComponentType.seminar,
      GradeComponentRecordType.laboratory => GradeComponentType.laboratory,
      GradeComponentRecordType.project => GradeComponentType.project,
      GradeComponentRecordType.coursework => GradeComponentType.coursework,
      GradeComponentRecordType.other => GradeComponentType.other,
    };
  }

  GradeComponentRecordType _componentRecordTypeFromLabel(String label) {
    return switch (label.trim().toLowerCase()) {
      'curs' || 'examen' => GradeComponentRecordType.exam,
      'seminar' => GradeComponentRecordType.seminar,
      'laborator' => GradeComponentRecordType.laboratory,
      'proiect' => GradeComponentRecordType.project,
      'activitate pe parcurs' => GradeComponentRecordType.coursework,
      _ => GradeComponentRecordType.other,
    };
  }

  GradeComponentType _componentTypeFromLabel(String label) {
    return switch (label.trim().toLowerCase()) {
      'curs' || 'examen' => GradeComponentType.exam,
      'seminar' => GradeComponentType.seminar,
      'laborator' => GradeComponentType.laboratory,
      'proiect' => GradeComponentType.project,
      'activitate pe parcurs' => GradeComponentType.coursework,
      _ => GradeComponentType.other,
    };
  }

  String _canonicalComponentName(String label) {
    return switch (label.trim()) {
      'Curs' => 'Examen',
      String value when value.isNotEmpty => value,
      _ => 'Alta componenta',
    };
  }

  bool _isEliminatoryComponent(String label) {
    return switch (_componentTypeFromLabel(label)) {
      GradeComponentType.seminar ||
      GradeComponentType.laboratory ||
      GradeComponentType.project => true,
      _ => false,
    };
  }

  String _standingLabel(AcademicStanding standing) {
    return switch (standing) {
      AcademicStanding.integralist => 'Integralist',
      AcademicStanding.restantier => 'Restantier',
      AcademicStanding.incomplet => 'Incomplet',
    };
  }
}
