import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/screens/ui/grades_screen_view.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  static const String _allSubjectsValue = '__all__';
  static const List<String> _courseTypeOptions = <String>[
    'Curs',
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
    unawaited(_initializeGradesData());
    unawaited(_loadTypeWeights());
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
    super.dispose();
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
      final Map<String, double> grades =
          await _repository.fetchGradeTypeGrades();
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
      final Map<String, double> weights =
          await _repository.fetchGradeTypeWeights();
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
          _typeWeights[
            _weightKey(subjectName: subjectName, courseType: entry.key)
          ] = entry.value;
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
    await _saveTypeWeights(subjectName: subjectName, weightsByType: <String, double>{});
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
              text: existing?.toString() ?? '',
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
                          labelText: 'Nota (1 - 10)',
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
                            final String text = controller.text
                                .trim()
                                .replaceAll(',', '.');
                            final double? parsed = double.tryParse(text);
                            if (parsed == null || parsed < 1 || parsed > 10) {
                              setModalState(() {
                                errorText =
                                    'Introdu o nota valida intre 1 si 10.';
                              });
                              return;
                            }

                            Navigator.of(
                              dialogContext,
                            ).pop(_TypeGradeDialogResult.save(parsed));
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
    final Map<String, double?> existing = <String, double?>{};
    for (final String courseType in _courseTypeOptions) {
      final String key =
          _weightKey(subjectName: subjectName, courseType: courseType);
      existing[courseType] = _typeWeights[key];
    }

    final Map<String, TextEditingController> controllers =
        <String, TextEditingController>{
      for (final String courseType in _courseTypeOptions)
        courseType: TextEditingController(
          text: existing[courseType]?.toString() ?? '',
        ),
    };

    final _TypeWeightDialogResult? result =
        await showDialog<_TypeWeightDialogResult>(
          context: context,
          builder: (BuildContext dialogContext) {
            String? errorText;

            double _parseValue(String raw) {
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
                          ..._courseTypeOptions.map(
                            (String courseType) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TextField(
                                controller: controllers[courseType],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                              Navigator.of(dialogContext).pop(
                                const _TypeWeightDialogResult.delete(),
                              );
                            },
                            child: const Text('Reseteaza ponderi'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Renunta'),
                        ),
                        FilledButton(
                          onPressed: () {
                            final Map<String, double> parsed =
                                <String, double>{};
                            double total = 0;

                            for (final String courseType
                                in _courseTypeOptions) {
                              final double value = _parseValue(
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
                                errorText =
                                    'Suma ponderilor trebuie sa fie 100%.';
                              });
                              return;
                            }

                            Navigator.of(dialogContext).pop(
                              _TypeWeightDialogResult.save(parsed),
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

    if (result.delete) {
      await _resetTypeWeights(subjectName);
      return;
    }

    await _saveTypeWeights(
      subjectName: subjectName,
      weightsByType: result.weightsByType,
    );
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

  double? _calculateSubjectAverage({
    required Map<String, double?> gradesByType,
    required Map<String, double?> weightsByType,
  }) {
    final bool hasWeights = weightsByType.values.any(
      (double? value) => value != null && value > 0,
    );

    if (!hasWeights) {
      final List<double> values =
          gradesByType.values.whereType<double>().toList(growable: false);
      if (values.isEmpty) {
        return null;
      }

      final double sum = values.fold<double>(
        0,
        (double acc, double v) => acc + v,
      );
      return sum / values.length;
    }

    double totalWeight = 0;
    double weightedSum = 0;

    for (final String courseType in _courseTypeOptions) {
      final double weight = weightsByType[courseType] ?? 0;
      if (weight <= 0) {
        continue;
      }

      final double? grade = gradesByType[courseType];
      if (grade == null) {
        return null;
      }

      totalWeight += weight;
      weightedSum += grade * (weight / 100);
    }

    if ((totalWeight - 100).abs() > 0.01) {
      return null;
    }

    return weightedSum;
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

      final Map<String, double?> gradesByType = <String, double?>{};
      final Map<String, double?> weightsByType = <String, double?>{};
      for (final String courseType in _courseTypeOptions) {
        final String key = _gradeKey(
          subjectName: subjectName,
          courseType: courseType,
        );
        gradesByType[courseType] = _typeGrades[key];

        final String weightKey = _weightKey(
          subjectName: subjectName,
          courseType: courseType,
        );
        weightsByType[courseType] = _typeWeights[weightKey];
      }

      cards.add(
        SubjectNoteCardData(
          subjectName: subjectName,
          gradesByType: gradesByType,
          weightsByType: weightsByType,
          average: _calculateSubjectAverage(
            gradesByType: gradesByType,
            weightsByType: weightsByType,
          ),
        ),
      );
    }

    return cards;
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
