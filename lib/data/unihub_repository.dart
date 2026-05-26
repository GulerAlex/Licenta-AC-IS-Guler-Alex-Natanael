import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/models/profile_stats.dart';
import 'package:unihub/models/user_profile.dart';

class UniHubRepository {
  UniHubRepository._();

  static final UniHubRepository instance = UniHubRepository._();
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

    return updatedRows.length;
  }

  Future<void> clearUserCourses() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('courses').delete().eq('user_id', user.id);
  }

  Future<void> replaceUserCourses(List<Course> courses) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('courses').delete().eq('user_id', user.id);

    if (courses.isEmpty) {
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

    await _client.from('grade_type_grades').upsert(
      <String, dynamic>{
        'user_id': user.id,
        'subject_name': normalizedSubject,
        'course_type': normalizedType,
        'score': score,
      },
      onConflict: 'user_id,subject_name,course_type',
    );
  }

  Future<void> upsertGradeTypeGrades(
    List<Map<String, dynamic>> items,
  ) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    if (items.isEmpty) {
      return;
    }

    final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> item in items) {
      final String subjectName = (item['subject_name'] as String?)?.trim() ?? '';
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

    await _client.from('grade_type_grades').upsert(
      payload,
      onConflict: 'user_id,subject_name,course_type',
    );
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

    await _client.from('resource_notes').upsert(
      <String, dynamic>{
        'user_id': user.id,
        'note_date': normalizedDate,
        'note_text': normalizedNote,
      },
      onConflict: 'user_id,note_date',
    );
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

    await _client.from('resource_notes').upsert(
      payload,
      onConflict: 'user_id,note_date',
    );
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

    final int? normalizedStudyYear =
        (studyYear != null && studyYear > 0) ? studyYear : null;

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

  Future<ProfileStats> fetchProfileStats() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final List<dynamic> courseRows = await _client
        .from('courses')
        .select('name, credits')
        .eq('user_id', user.id);

    final Map<String, int> creditsBySubject = <String, int>{};
    for (final dynamic row in courseRows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }
      final String subjectName = (row['name'] as String?)?.trim() ?? '';
      if (subjectName.isEmpty) {
        continue;
      }

      final dynamic creditsRaw = row['credits'];
      final int parsedCredits = switch (creditsRaw) {
        int value => value,
        num value => value.toInt(),
        String value => int.tryParse(value) ?? 0,
        _ => 0,
      };
      final int normalizedCredits = parsedCredits < 0 ? 0 : parsedCredits;
      final int existing = creditsBySubject[subjectName] ?? 0;
      if (normalizedCredits > existing) {
        creditsBySubject[subjectName] = normalizedCredits;
      }
    }

    final int totalSubjects = creditsBySubject.length;
    final int totalCredits = creditsBySubject.values.fold<int>(
      0,
      (int acc, int value) => acc + value,
    );

    final List<dynamic> gradeRows = await _client
        .from('grade_type_grades')
        .select('subject_name, score')
        .eq('user_id', user.id);

    final Set<String> knownSubjects = creditsBySubject.keys.toSet();
    final Map<String, List<double>> gradesBySubject =
        <String, List<double>>{};

    for (final dynamic row in gradeRows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }

      final String subjectName =
          (row['subject_name'] as String?)?.trim() ?? '';
      if (subjectName.isEmpty) {
        continue;
      }
      if (knownSubjects.isNotEmpty && !knownSubjects.contains(subjectName)) {
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

      gradesBySubject.putIfAbsent(subjectName, () => <double>[]).add(score);
    }

    double? overallAverage;
    if (gradesBySubject.isNotEmpty) {
      double sum = 0;
      int count = 0;
      for (final List<double> values in gradesBySubject.values) {
        if (values.isEmpty) {
          continue;
        }
        final double subjectAverage =
            values.fold<double>(0, (double acc, double v) => acc + v) /
                values.length;
        sum += subjectAverage;
        count += 1;
      }
      overallAverage = count == 0 ? null : sum / count;
    }

    return ProfileStats(
      totalSubjects: totalSubjects,
      totalCredits: totalCredits,
      overallAverage: overallAverage,
    );
  }
}
