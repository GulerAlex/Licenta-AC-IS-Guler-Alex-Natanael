class GradeItem {
  const GradeItem({
    required this.subject,
    required this.score,
    required this.credits,
  });

  final String subject;
  final double score;
  final int credits;

  factory GradeItem.fromMap(Map<String, dynamic> map) {
    final dynamic scoreRaw = map['score'];
    final dynamic creditsRaw = map['credits'];

    final double parsedScore = switch (scoreRaw) {
      num value => value.toDouble(),
      String value => double.tryParse(value) ?? 0,
      _ => 0,
    };

    final int parsedCredits = switch (creditsRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value) ?? 0,
      _ => 0,
    };

    return GradeItem(
      subject: (map['subject'] as String?) ?? '',
      score: parsedScore,
      credits: parsedCredits,
    );
  }
}
