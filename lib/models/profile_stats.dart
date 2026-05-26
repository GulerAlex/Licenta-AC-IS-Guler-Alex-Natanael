class ProfileStats {
  const ProfileStats({
    required this.totalSubjects,
    required this.promotedSubjects,
    required this.failedSubjects,
    required this.incompleteSubjects,
    required this.notStartedSubjects,
    required this.totalCredits,
    required this.earnedCredits,
    required this.failedCredits,
    required this.incompleteCredits,
    required this.remainingCredits,
    required this.standingLabel,
    required this.overallAverage,
    required this.estimatedAverage,
  });

  final int totalSubjects;
  final int promotedSubjects;
  final int failedSubjects;
  final int incompleteSubjects;
  final int notStartedSubjects;
  final int totalCredits;
  final int earnedCredits;
  final int failedCredits;
  final int incompleteCredits;
  final int remainingCredits;
  final String standingLabel;
  final double? overallAverage;
  final double? estimatedAverage;
}
