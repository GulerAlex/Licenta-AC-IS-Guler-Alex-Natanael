class SubjectScheduleEntry {
  const SubjectScheduleEntry({
    required this.name,
    required this.semesterLabel,
    required this.credits,
    required this.sessionType,
    required this.weekdayLabel,
    required this.time,
    required this.room,
    required this.professor,
    required this.sortOrder,
    required this.subjectId,
    required this.sessionId,
  });

  final String name;
  final String semesterLabel;
  final int credits;
  final String sessionType;
  final String weekdayLabel;
  final String time;
  final String room;
  final String professor;
  final int sortOrder;
  final String subjectId;
  final String sessionId;
}
