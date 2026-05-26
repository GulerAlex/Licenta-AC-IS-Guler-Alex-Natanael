class ProfileStats {
  const ProfileStats({
    required this.totalSubjects,
    required this.totalCredits,
    required this.overallAverage,
  });

  final int totalSubjects;
  final int totalCredits;
  final double? overallAverage;
}
