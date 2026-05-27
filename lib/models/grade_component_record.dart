enum GradeComponentRecordType {
  exam,
  seminar,
  laboratory,
  project,
  coursework,
  other,
}

const String defaultGradeComponentName = 'Examen';
const String fallbackGradeComponentName = 'Alta componenta';

const List<String> gradeComponentLabels = <String>[
  defaultGradeComponentName,
  'Seminar',
  'Laborator',
  'Proiect',
  'Activitate pe parcurs',
  fallbackGradeComponentName,
];

const List<String> weightedGradeComponentLabels = <String>[
  defaultGradeComponentName,
  'Seminar',
  'Laborator',
];

class GradeComponentRecord {
  const GradeComponentRecord({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.type,
    required this.weightPercent,
    required this.minimumGrade,
    required this.grade,
    required this.isRequired,
    required this.isEliminatory,
  });

  final String id;
  final String subjectId;
  final String name;
  final GradeComponentRecordType type;
  final double weightPercent;
  final double minimumGrade;
  final double? grade;
  final bool isRequired;
  final bool isEliminatory;

  factory GradeComponentRecord.fromMap(Map<String, dynamic> map) {
    return GradeComponentRecord(
      id: (map['id'] as String?) ?? '',
      subjectId: (map['subject_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      type: _typeFromStorage((map['component_type'] as String?) ?? ''),
      weightPercent: _parseDouble(
        map['weight_percent'],
        fallback: 0,
      ).clamp(0, 100),
      minimumGrade: _parseDouble(
        map['minimum_grade'],
        fallback: 5,
      ).clamp(1, 10),
      grade: _parseNullableGrade(map['grade']),
      isRequired: (map['is_required'] as bool?) ?? true,
      isEliminatory: (map['is_eliminatory'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toSupabasePayload({required String userId}) {
    return <String, dynamic>{
      'user_id': userId,
      'subject_id': subjectId,
      'name': name.trim(),
      'component_type': type.name,
      'weight_percent': weightPercent,
      'minimum_grade': minimumGrade,
      'grade': grade,
      'is_required': isRequired,
      'is_eliminatory': isEliminatory,
    };
  }
}

GradeComponentRecordType gradeComponentRecordTypeFromLabel(String label) {
  return switch (label.trim().toLowerCase()) {
    'curs' || 'examen' => GradeComponentRecordType.exam,
    'seminar' => GradeComponentRecordType.seminar,
    'laborator' => GradeComponentRecordType.laboratory,
    'proiect' => GradeComponentRecordType.project,
    'activitate pe parcurs' => GradeComponentRecordType.coursework,
    _ => GradeComponentRecordType.other,
  };
}

String canonicalGradeComponentName(String label) {
  return switch (label.trim().toLowerCase()) {
    'curs' || 'examen' => defaultGradeComponentName,
    'seminar' => 'Seminar',
    'laborator' => 'Laborator',
    'proiect' => 'Proiect',
    'activitate pe parcurs' => 'Activitate pe parcurs',
    String value when value.isNotEmpty => label.trim(),
    _ => fallbackGradeComponentName,
  };
}

bool isEliminatoryGradeComponent(String label) {
  return switch (gradeComponentRecordTypeFromLabel(label)) {
    GradeComponentRecordType.seminar ||
    GradeComponentRecordType.laboratory ||
    GradeComponentRecordType.project => true,
    _ => false,
  };
}

GradeComponentRecordType _typeFromStorage(String value) {
  return GradeComponentRecordType.values.firstWhere(
    (GradeComponentRecordType type) => type.name == value.trim(),
    orElse: () => GradeComponentRecordType.other,
  );
}

double _parseDouble(dynamic value, {required double fallback}) {
  return switch (value) {
    int parsed => parsed.toDouble(),
    num parsed => parsed.toDouble(),
    String parsed => double.tryParse(parsed) ?? fallback,
    _ => fallback,
  };
}

double? _parseNullableGrade(dynamic value) {
  final double? parsed = switch (value) {
    int parsed => parsed.toDouble(),
    num parsed => parsed.toDouble(),
    String parsed => double.tryParse(parsed),
    _ => null,
  };
  if (parsed == null || parsed < 1 || parsed > 10) {
    return null;
  }
  return parsed;
}
