import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/models/academic_progress.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/services/academic_progress_calculator.dart';
import 'package:unihub/screens/ui/grades_screen_view.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({
    super.key,
    required this.coursesVersion,
    required this.isActive,
  });

  final int coursesVersion;
  final bool isActive;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  static const String _allSubjectsValue = '__all__';
  static const List<String> _courseTypeOptions = <String>[
    'Examen',
    'Seminar',
    'Laborator',
    'Proiect',
    'Activitate pe parcurs',
    'Alta componenta',
  ];
  static const List<String> _weightTypeOptions = <String>[
    'Examen',
    'Seminar',
    'Laborator',
  ];

  late Future<List<Course>> _coursesFuture;
  String _selectedSubject = _allSubjectsValue;
  Map<String, double> _typeGrades = <String, double>{};
  Map<String, double> _typeWeights = <String, double>{};
  RealtimeChannel? _coursesRealtimeChannel;
  RealtimeChannel? _gradesRealtimeChannel;
  RealtimeChannel? _weightsRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _coursesFuture = _repository.fetchUserCourses();
    _subscribeToCoursesRealtime();
    _subscribeToGradesRealtime();
    _subscribeToWeightsRealtime();
    _repository.coursesVersion.addListener(_handleCoursesChanged);
    unawaited(_initializeGradesData());
    unawaited(_loadTypeWeights());
  }

  @override
  void didUpdateWidget(covariant GradesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coursesVersion != widget.coursesVersion ||
        (!oldWidget.isActive && widget.isActive)) {
      _refreshCourses();
    }
  }

  @override
  void dispose() {
    final RealtimeChannel? coursesChannel = _coursesRealtimeChannel;
    if (coursesChannel != null) {
      Supabase.instance.client.removeChannel(coursesChannel);
    }
    final RealtimeChannel? gradesChannel = _gradesRealtimeChannel;
    if (gradesChannel != null) {
      Supabase.instance.client.removeChannel(gradesChannel);
    }
    final RealtimeChannel? weightsChannel = _weightsRealtimeChannel;
    if (weightsChannel != null) {
      Supabase.instance.client.removeChannel(weightsChannel);
    }
    _repository.coursesVersion.removeListener(_handleCoursesChanged);
    super.dispose();
  }

  void _handleCoursesChanged() {
    _refreshCourses();
  }

  void _refreshCourses() {
    if (!mounted) {
      return;
    }
    setState(() {
      _coursesFuture = _repository.fetchUserCourses();
    });
  }

  void _subscribeToCoursesRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('note-courses-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'courses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _coursesFuture = _repository.fetchUserCourses();
            });
          },
        )
        .subscribe();

    _coursesRealtimeChannel = channel;
  }

  void _subscribeToGradesRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('grade-grades-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'grade_type_grades',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            unawaited(_loadTypeGrades());
          },
        )
        .subscribe();

    _gradesRealtimeChannel = channel;
  }

  void _subscribeToWeightsRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('grade-weights-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'grade_type_weights',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            unawaited(_loadTypeWeights());
          },
        )
        .subscribe();

    _weightsRealtimeChannel = channel;
  }

  Future<void> _reload() async {
    setState(() {
      _coursesFuture = _repository.fetchUserCourses();
    });
    await _coursesFuture;
    await _loadTypeGrades();
    await _loadTypeWeights();
  }

  String _notesStorageKey() {
    final String userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    return 'note_type_grades_$userId';
  }

  String _gradeKey({required String subjectName, required String courseType}) {
    return '${subjectName.trim()}|${courseType.trim()}';
  }

  String _weightKey({required String subjectName, required String courseType}) {
    return '${subjectName.trim()}|${courseType.trim()}';
  }

  GradeComponentType _componentTypeFromLabel(String label) {
    return switch (label.trim().toLowerCase()) {
      'curs' || 'examen' => GradeComponentType.exam,
      'seminar' => GradeComponentType.seminar,
      'laborator' => GradeComponentType.laboratory,
      'proiect' => GradeComponentType.project,
      'activitate pe parcurs' => GradeComponentType.coursework,
      _ => GradeComponentType.other,
    };
  }

  String _canonicalComponentName(String label) {
    return switch (label.trim().toLowerCase()) {
      'curs' || 'examen' => 'Examen',
      'seminar' => 'Seminar',
      'laborator' => 'Laborator',
      'proiect' => 'Proiect',
      'activitate pe parcurs' => 'Activitate pe parcurs',
      String value when value.isNotEmpty => label.trim(),
      _ => 'Alta componenta',
    };
  }

  bool _isEliminatoryComponent(String label) {
    return switch (_componentTypeFromLabel(label)) {
      GradeComponentType.seminar ||
      GradeComponentType.laboratory ||
      GradeComponentType.project => true,
      _ => false,
    };
  }

  double? _gradeForComponent({
    required String subjectName,
    required String componentName,
  }) {
    return _typeGrades[_gradeKey(
          subjectName: subjectName,
          courseType: componentName,
        )] ??
        (componentName == 'Examen'
            ? _typeGrades[_gradeKey(
                subjectName: subjectName,
                courseType: 'Curs',
              )]
            : null);
  }

  double? _weightForComponent({
    required String subjectName,
    required String componentName,
  }) {
    return _typeWeights[_weightKey(
          subjectName: subjectName,
          courseType: componentName,
        )] ??
        (componentName == 'Examen'
            ? _typeWeights[_weightKey(
                subjectName: subjectName,
                courseType: 'Curs',
              )]
            : null);
  }

  Future<void> _initializeGradesData() async {
    await _migrateLocalGradesIfNeeded();
    await _loadTypeGrades();
  }

  Future<void> _migrateLocalGradesIfNeeded() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_notesStorageKey());
    if (raw == null || raw.isEmpty) {
      return;
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    decoded.forEach((dynamic key, dynamic value) {
      final String parsedKey = key.toString().trim();
      if (parsedKey.isEmpty || !parsedKey.contains('|')) {
        return;
      }

      final List<String> parts = parsedKey.split('|');
      if (parts.length != 2) {
        return;
      }

      final String subjectName = parts[0].trim();
      final String courseType = parts[1].trim();
      final double? parsedValue = switch (value) {
        num numericValue => numericValue.toDouble(),
        String textValue => double.tryParse(textValue),
        _ => null,
      };

      if (subjectName.isEmpty || courseType.isEmpty) {
        return;
      }

      if (parsedValue == null || parsedValue < 1 || parsedValue > 10) {
        return;
      }

      items.add(<String, dynamic>{
        'subject_name': subjectName,
        'course_type': courseType,
        'score': parsedValue,
      });
    });

    if (items.isEmpty) {
      return;
    }

    try {
      await _repository.upsertGradeTypeGrades(items);
      await prefs.remove(_notesStorageKey());
    } catch (e) {
      debugPrint('Failed to migrate local grades: $e');
    }
  }

  Future<void> _loadTypeGrades() async {
    try {
      final Map<String, double> grades = await _repository
          .fetchGradeTypeGrades();
      if (!mounted) {
        return;
      }
      setState(() {
        _typeGrades = grades;
      });
    } catch (e) {
      debugPrint('Failed to load grade entries: $e');
    }
  }

  Future<void> _loadTypeWeights() async {
    try {
      final Map<String, double> weights = await _repository
          .fetchGradeTypeWeights();
      if (!mounted) {
        return;
      }
      setState(() {
        _typeWeights = weights;
      });
    } catch (e) {
      debugPrint('Failed to load grade weights: $e');
    }
  }

  Future<void> _saveTypeGrade({
    required String subjectName,
    required String courseType,
    required double? value,
  }) async {
    try {
      await _repository.setGradeTypeGrade(
        subjectName: subjectName,
        courseType: courseType,
        score: value,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final String key = _gradeKey(
          subjectName: subjectName,
          courseType: courseType,
        );
        if (value == null) {
          _typeGrades.remove(key);
        } else {
          _typeGrades[key] = value;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-a putut salva nota.')),
        );
      }
    }
  }

  Future<void> _saveTypeWeights({
    required String subjectName,
    required Map<String, double> weightsByType,
  }) async {
    try {
      await _repository.setGradeTypeWeights(
        subjectName: subjectName,
        weightsByType: weightsByType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _typeWeights.removeWhere(
          (String key, double _) => key.startsWith('${subjectName.trim()}|'),
        );
        for (final MapEntry<String, double> entry in weightsByType.entries) {
          _typeWeights[_weightKey(
                subjectName: subjectName,
                courseType: entry.key,
              )] =
              entry.value;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-au putut salva ponderile.')),
        );
      }
    }
  }

  Future<void> _resetTypeWeights(String subjectName) async {
    await _saveTypeWeights(
      subjectName: subjectName,
      weightsByType: <String, double>{},
    );
  }

  Future<void> _openTypeGradeDialog(
    String subjectName,
    String courseType,
  ) async {
    final String key = _gradeKey(
      subjectName: subjectName,
      courseType: courseType,
    );
    final double? existing = _typeGrades[key];

    final _TypeGradeDialogResult? result =
        await showDialog<_TypeGradeDialogResult>(
          context: context,
          builder: (BuildContext dialogContext) {
            final TextEditingController controller = TextEditingController(
              text: existing == null ? '' : existing.toStringAsFixed(0),
            );
            String? errorText;

            return StatefulBuilder(
              builder:
                  (
                    BuildContext context,
                    void Function(void Function()) setModalState,
                  ) {
                    return AlertDialog(
                      title: Text('$subjectName - $courseType'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Nota UPT (1 - 10)',
                          helperText: 'Se accepta doar note intregi.',
                          errorText: errorText,
                        ),
                      ),
                      actions: <Widget>[
                        if (existing != null)
                          TextButton(
                            onPressed: () {
                              Navigator.of(
                                dialogContext,
                              ).pop(const _TypeGradeDialogResult.delete());
                            },
                            child: const Text('Sterge nota'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Renunta'),
                        ),
                        FilledButton(
                          onPressed: () {
                            final String text = controller.text.trim();
                            final int? parsed = int.tryParse(text);
                            if (parsed == null || parsed < 1 || parsed > 10) {
                              setModalState(() {
                                errorText =
                                    'Introdu o nota intreaga intre 1 si 10.';
                              });
                              return;
                            }

                            Navigator.of(dialogContext).pop(
                              _TypeGradeDialogResult.save(parsed.toDouble()),
                            );
                          },
                          child: const Text('Salveaza'),
                        ),
                      ],
                    );
                  },
            );
          },
        );

    if (result == null || !mounted) {
      return;
    }

    await _saveTypeGrade(
      subjectName: subjectName,
      courseType: courseType,
      value: result.delete ? null : result.value,
    );
  }

  Future<void> _openTypeWeightDialog(String subjectName) async {
    final List<Course> courses;
    try {
      courses = await _coursesFuture;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-au putut incarca materiile.')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final List<String> activeWeightTypes = _activeWeightTypes(
      subjectName: subjectName,
      courses: courses,
    );
    final Map<String, double?> existing = <String, double?>{};
    for (final String courseType in activeWeightTypes) {
      existing[courseType] = _weightForComponent(
        subjectName: subjectName,
        componentName: courseType,
      );
    }

    final Map<String, TextEditingController> controllers =
        <String, TextEditingController>{
          for (final String courseType in activeWeightTypes)
            courseType: TextEditingController(
              text: existing[courseType]?.toString() ?? '',
            ),
        };

    final _TypeWeightDialogResult?
    result = await showDialog<_TypeWeightDialogResult>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? errorText;

        double parseValue(String raw) {
          final String cleaned = raw.trim().replaceAll(',', '.');
          if (cleaned.isEmpty) {
            return 0;
          }
          return double.tryParse(cleaned) ?? double.nan;
        }

        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setModalState,
              ) {
                return AlertDialog(
                  title: Text('Ponderi - $subjectName'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ...activeWeightTypes.map(
                        (String courseType) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: controllers[courseType],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '$courseType (%)',
                            ),
                          ),
                        ),
                      ),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: <Widget>[
                    if (existing.values.any((double? v) => v != null))
                      TextButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(const _TypeWeightDialogResult.delete());
                        },
                        child: const Text('Reseteaza ponderi'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Renunta'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final Map<String, double> parsed = <String, double>{};
                        double total = 0;

                        for (final String courseType in activeWeightTypes) {
                          final double value = parseValue(
                            controllers[courseType]?.text ?? '',
                          );

                          if (value.isNaN || value < 0 || value > 100) {
                            setModalState(() {
                              errorText =
                                  'Introdu ponderi valide intre 0 si 100.';
                            });
                            return;
                          }

                          total += value;
                          if (value > 0) {
                            parsed[courseType] = value;
                          }
                        }

                        if ((total - 100).abs() > 0.01) {
                          setModalState(() {
                            errorText = 'Suma ponderilor trebuie sa fie 100%.';
                          });
                          return;
                        }

                        Navigator.of(
                          dialogContext,
                        ).pop(_TypeWeightDialogResult.save(parsed));
                      },
                      child: const Text('Salveaza'),
                    ),
                  ],
                );
              },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    if (result.delete) {
      await _resetTypeWeights(subjectName);
      return;
    }

    await _saveTypeWeights(
      subjectName: subjectName,
      weightsByType: result.weightsByType,
    );
  }

  List<String> _activeWeightTypes({
    required String subjectName,
    required List<Course> courses,
  }) {
    final Set<String> activeTypes = courses
        .where((Course course) => course.name.trim() == subjectName.trim())
        .map((Course course) => _canonicalComponentName(course.courseType))
        .where(_weightTypeOptions.contains)
        .toSet();

    if (activeTypes.isEmpty) {
      activeTypes.add('Examen');
    }

    return _weightTypeOptions
        .where(activeTypes.contains)
        .toList(growable: false);
  }

  List<String> _subjectOptions(List<Course> courses) {
    final Set<String> subjectSet = courses
        .map((Course course) => course.name.trim())
        .where((String subject) => subject.isNotEmpty)
        .toSet();

    final List<String> subjects = subjectSet.toList(
      growable: false,
    )..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return <String>[_allSubjectsValue, ...subjects];
  }

  AcademicSubject _buildAcademicSubject({
    required String subjectName,
    required List<Course> courses,
  }) {
    final List<Course> subjectCourses = courses
        .where((Course course) => course.name.trim() == subjectName)
        .toList(growable: false);
    final int credits = subjectCourses.fold<int>(
      0,
      (int currentMax, Course course) =>
          course.credits > currentMax ? course.credits : currentMax,
    );
    final String semester = subjectCourses.isEmpty
        ? ''
        : subjectCourses.first.semesterLabel;

    final Set<String> componentNames = <String>{
      ...subjectCourses
          .map((Course course) => _canonicalComponentName(course.courseType))
          .where((String type) => type.isNotEmpty),
    };

    if (componentNames.isEmpty) {
      componentNames.add('Examen');
    }

    final bool hasConfiguredWeights = componentNames.any(
      (String componentName) =>
          (_weightForComponent(
                subjectName: subjectName,
                componentName: componentName,
              ) ??
              0) >
          0,
    );
    final double defaultWeight = componentNames.isEmpty
        ? 0
        : 1 / componentNames.length;

    final List<GradeComponent> components =
        componentNames
            .map((String componentName) {
              return GradeComponent(
                id: '$subjectName|$componentName',
                name: componentName,
                type: _componentTypeFromLabel(componentName),
                grade: _gradeForComponent(
                  subjectName: subjectName,
                  componentName: componentName,
                ),
                weight: hasConfiguredWeights
                    ? ((_weightForComponent(
                                subjectName: subjectName,
                                componentName: componentName,
                              ) ??
                              0) /
                          100)
                    : defaultWeight,
                isRequired: true,
                isEliminatory: _isEliminatoryComponent(componentName),
              );
            })
            .toList(growable: false)
          ..sort((GradeComponent a, GradeComponent b) {
            final int aIndex = _courseTypeOptions.indexOf(a.name);
            final int bIndex = _courseTypeOptions.indexOf(b.name);
            final int normalizedA = aIndex == -1
                ? _courseTypeOptions.length
                : aIndex;
            final int normalizedB = bIndex == -1
                ? _courseTypeOptions.length
                : bIndex;
            return normalizedA.compareTo(normalizedB);
          });

    return AcademicSubject(
      id: subjectName,
      name: subjectName,
      semester: semester,
      year: 0,
      credits: credits,
      components: components,
    );
  }

  List<SubjectNoteCardData> _buildSubjectCards({
    required List<Course> courses,
    required String selectedSubject,
  }) {
    final List<String> subjects =
        courses
            .map((Course course) => course.name.trim())
            .where((String subject) => subject.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort(
            (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
          );

    final List<SubjectNoteCardData> cards = <SubjectNoteCardData>[];

    for (final String subjectName in subjects) {
      if (selectedSubject != _allSubjectsValue &&
          selectedSubject != subjectName) {
        continue;
      }

      final AcademicSubject subject = _buildAcademicSubject(
        subjectName: subjectName,
        courses: courses,
      );
      final SubjectEvaluation evaluation =
          AcademicProgressCalculator.evaluateSubject(subject);

      cards.add(
        SubjectNoteCardData(subjectName: subjectName, evaluation: evaluation),
      );
    }

    return cards;
  }

  int _totalCredits(List<SubjectNoteCardData> cards) {
    return cards.fold<int>(
      0,
      (int total, SubjectNoteCardData card) =>
          total + card.evaluation.subject.credits,
    );
  }

  int _earnedCredits(List<SubjectNoteCardData> cards) {
    return cards.fold<int>(
      0,
      (int total, SubjectNoteCardData card) =>
          total + card.evaluation.earnedCredits,
    );
  }

  double? _weightedAverage(List<SubjectNoteCardData> cards) {
    double weightedSum = 0;
    int creditsWithGrades = 0;

    for (final SubjectNoteCardData card in cards) {
      final double? average = card.evaluation.finalGrade;
      final int credits = card.evaluation.subject.credits;
      if (average == null || credits <= 0 || !card.evaluation.isPromoted) {
        continue;
      }

      weightedSum += average * credits;
      creditsWithGrades += credits;
    }

    if (creditsWithGrades == 0) {
      return null;
    }

    return weightedSum / creditsWithGrades;
  }

  void _changeSelectedSubject(String subject) {
    if (subject == _selectedSubject) {
      return;
    }

    setState(() {
      _selectedSubject = subject;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Course>>(
      future: _coursesFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return GradesLoadError(onRetry: _reload);
        }

        final List<Course> courses = snapshot.data ?? <Course>[];
        final List<String> subjectOptions = _subjectOptions(courses);
        final String selectedSubject = subjectOptions.contains(_selectedSubject)
            ? _selectedSubject
            : _allSubjectsValue;
        final List<SubjectNoteCardData> subjectCards = _buildSubjectCards(
          courses: courses,
          selectedSubject: selectedSubject,
        );

        return GradesScreenView(
          subjectCards: subjectCards,
          totalCredits: _totalCredits(subjectCards),
          earnedCredits: _earnedCredits(subjectCards),
          weightedAverage: _weightedAverage(subjectCards),
          onRefresh: _reload,
          allSubjectsValue: _allSubjectsValue,
          selectedSubject: selectedSubject,
          subjectOptions: subjectOptions,
          onSubjectChanged: _changeSelectedSubject,
          totalSubjectsCount: subjectOptions.length - 1,
          onEditTypeGrade: _openTypeGradeDialog,
          onEditTypeWeights: _openTypeWeightDialog,
          onResetTypeWeights: _resetTypeWeights,
        );
      },
    );
  }
}

class _TypeGradeDialogResult {
  const _TypeGradeDialogResult.save(this.value) : delete = false;
  const _TypeGradeDialogResult.delete() : value = null, delete = true;

  final double? value;
  final bool delete;
}

class _TypeWeightDialogResult {
  const _TypeWeightDialogResult.save(this.weightsByType) : delete = false;
  const _TypeWeightDialogResult.delete()
    : weightsByType = const <String, double>{},
      delete = true;

  final Map<String, double> weightsByType;
  final bool delete;
}
