enum SubjectStatus { promoted, failed, incomplete, notStarted }

enum GradeComponentType {
  exam,
  seminar,
  laboratory,
  project,
  coursework,
  other,
}

enum AcademicStanding { integralist, restantier, incomplet }

class GradeComponent {
  const GradeComponent({
    required this.id,
    required this.name,
    required this.type,
    required this.weight,
    required this.isRequired,
    required this.isEliminatory,
    this.grade,
    this.minGrade = 5,
  });

  final String id;
  final String name;
  final double? grade;
  final double weight;
  final bool isRequired;
  final bool isEliminatory;
  final double minGrade;
  final GradeComponentType type;
}

class AcademicSubject {
  const AcademicSubject({
    required this.id,
    required this.name,
    required this.semester,
    required this.year,
    required this.credits,
    required this.components,
  });

  final String id;
  final String name;
  final String semester;
  final int year;
  final int credits;
  final List<GradeComponent> components;
}

class SubjectEvaluation {
  const SubjectEvaluation({
    required this.subject,
    required this.status,
    required this.earnedCredits,
    required this.missingRequiredComponents,
    required this.failingComponents,
    required this.hasConfigurationWarning,
    required this.configurationMessage,
    this.finalGrade,
    this.estimatedFinalGrade,
  });

  final AcademicSubject subject;
  final SubjectStatus status;
  final int earnedCredits;
  final double? finalGrade;
  final double? estimatedFinalGrade;
  final List<GradeComponent> missingRequiredComponents;
  final List<GradeComponent> failingComponents;
  final bool hasConfigurationWarning;
  final String? configurationMessage;

  bool get isPromoted => status == SubjectStatus.promoted;
}

class AcademicProgress {
  const AcademicProgress({
    required this.subjects,
    required this.totalEarnedCredits,
    required this.totalPossibleCredits,
    required this.failedCredits,
    required this.incompleteCredits,
    required this.remainingCredits,
    required this.standing,
    this.officialAverage,
    this.estimatedAverage,
  });

  final List<SubjectEvaluation> subjects;
  final int totalEarnedCredits;
  final int totalPossibleCredits;
  final int failedCredits;
  final int incompleteCredits;
  final int remainingCredits;
  final AcademicStanding standing;
  final double? officialAverage;
  final double? estimatedAverage;
}
