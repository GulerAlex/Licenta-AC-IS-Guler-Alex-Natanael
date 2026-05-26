class AcademicSubjectV2 {
  const AcademicSubjectV2({
    required this.id,
    required this.name,
    required this.semesterLabel,
    required this.credits,
    required this.professor,
    required this.colorHex,
    required this.archived,
  });

  final String id;
  final String name;
  final String semesterLabel;
  final int credits;
  final String professor;
  final String colorHex;
  final bool archived;

  factory AcademicSubjectV2.fromMap(Map<String, dynamic> map) {
    return AcademicSubjectV2(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      semesterLabel: (map['semester_label'] as String?) ?? 'Semestrul 1',
      credits: _parseInt(map['credits'], fallback: 5).clamp(1, 60),
      professor: (map['professor'] as String?) ?? '',
      colorHex: (map['color_hex'] as String?) ?? '#35B86F',
      archived: (map['archived'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toSupabasePayload({required String userId}) {
    return <String, dynamic>{
      'user_id': userId,
      'name': name.trim(),
      'semester_label': semesterLabel.trim(),
      'credits': credits,
      'professor': professor.trim(),
      'color_hex': colorHex.trim(),
      'archived': archived,
    };
  }

  AcademicSubjectV2 copyWith({
    String? id,
    String? name,
    String? semesterLabel,
    int? credits,
    String? professor,
    String? colorHex,
    bool? archived,
  }) {
    return AcademicSubjectV2(
      id: id ?? this.id,
      name: name ?? this.name,
      semesterLabel: semesterLabel ?? this.semesterLabel,
      credits: credits ?? this.credits,
      professor: professor ?? this.professor,
      colorHex: colorHex ?? this.colorHex,
      archived: archived ?? this.archived,
    );
  }
}

int _parseInt(dynamic value, {required int fallback}) {
  return switch (value) {
    int parsed => parsed,
    num parsed => parsed.toInt(),
    String parsed => int.tryParse(parsed) ?? fallback,
    _ => fallback,
  };
}
