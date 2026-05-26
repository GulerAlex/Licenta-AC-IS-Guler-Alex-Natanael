class Course {
  const Course({
    required this.name,
    required this.semesterLabel,
    required this.credits,
    required this.courseType,
    required this.weekdayLabel,
    required this.time,
    required this.room,
    required this.professor,
    required this.sortOrder,
    this.subjectId = '',
    this.sessionId = '',
  });

  final String name;
  final String semesterLabel;
  final int credits;
  final String courseType;
  final String weekdayLabel;
  final String time;
  final String room;
  final String professor;
  final int sortOrder;
  final String subjectId;
  final String sessionId;

  factory Course.fromMap(Map<String, dynamic> map) {
    final dynamic sortOrderRaw = map['sort_order'];
    final dynamic creditsRaw = map['credits'];
    final int parsedCredits = switch (creditsRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value) ?? 5,
      _ => 5,
    };

    return Course(
      name: (map['name'] as String?) ?? '',
      semesterLabel: (map['semester_label'] as String?) ?? 'Semestrul 2',
      credits: parsedCredits > 0 ? parsedCredits : 5,
      courseType: (map['course_type'] as String?) ?? 'Curs',
      weekdayLabel: (map['weekday_label'] as String?) ?? 'Luni',
      time: (map['time_label'] as String?) ?? '',
      room: (map['room'] as String?) ?? '',
      professor: (map['professor'] as String?) ?? '',
      sortOrder: switch (sortOrderRaw) {
        int value => value,
        num value => value.toInt(),
        String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
      subjectId: (map['subject_id'] as String?) ?? '',
      sessionId: (map['id'] as String?) ?? '',
    );
  }
}
