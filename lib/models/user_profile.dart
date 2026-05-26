class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.faculty,
    required this.studyYear,
    required this.universityEmail,
    required this.groupCode,
  });

  final String fullName;
  final String faculty;
  final int? studyYear;
  final String universityEmail;
  final String? groupCode;

  String get academicInfo {
    if (faculty.isEmpty && studyYear == null) {
      return 'Student';
    }
    if (studyYear == null) {
      return faculty;
    }
    if (faculty.isEmpty) {
      return 'Anul $studyYear';
    }
    return '$faculty • Anul $studyYear';
  }

  factory UserProfile.fromSupabase({
    required Map<String, dynamic>? row,
    required String fallbackEmail,
    required String fallbackName,
  }) {
    final String dbName = (row?['full_name'] as String?)?.trim() ?? '';
    final String dbFaculty = (row?['faculty'] as String?)?.trim() ?? '';
    final dynamic studyYearRaw = row?['study_year'];
    final int? dbStudyYear = switch (studyYearRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    final String dbEmail = (row?['university_email'] as String?)?.trim() ?? '';
    final String dbGroup = (row?['group_code'] as String?)?.trim() ?? '';

    return UserProfile(
      fullName: dbName.isNotEmpty ? dbName : fallbackName,
      faculty: dbFaculty,
      studyYear: dbStudyYear,
      universityEmail: dbEmail.isNotEmpty ? dbEmail : fallbackEmail,
      groupCode: dbGroup.isNotEmpty ? dbGroup : null,
    );
  }
}
