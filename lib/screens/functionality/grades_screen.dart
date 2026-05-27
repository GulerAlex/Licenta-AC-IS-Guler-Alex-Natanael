import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/models/academic_progress.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/services/academic_progress_calculator.dart';
import 'package:unihub/screens/ui/grades_screen_view.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({
    super.key,
    required this.academicDataVersion,
    required this.isActive,
  });

  final int academicDataVersion;
  final bool isActive;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;

  late Future<_GradesData> _gradesDataFuture;
  String _selectedSemester = UniHubRepository.availableSemesters.first;
  RealtimeChannel? _subjectsRealtimeChannel;
  RealtimeChannel? _sessionsRealtimeChannel;
  RealtimeChannel? _componentsRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _gradesDataFuture = _loadGradesData();
    _subscribeToSubjectsRealtime();
    _subscribeToSessionsRealtime();
    _subscribeToComponentsRealtime();
    _repository.academicDataVersion.addListener(_handleAcademicDataChanged);
    unawaited(_migrateLocalGradesIfNeeded());
  }

  @override
  void didUpdateWidget(covariant GradesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.academicDataVersion != widget.academicDataVersion ||
        (!oldWidget.isActive && widget.isActive)) {
      _refreshAcademicData();
    }
  }

  @override
  void dispose() {
    final RealtimeChannel? subjectsChannel = _subjectsRealtimeChannel;
    if (subjectsChannel != null) {
      Supabase.instance.client.removeChannel(subjectsChannel);
    }
    final RealtimeChannel? sessionsChannel = _sessionsRealtimeChannel;
    if (sessionsChannel != null) {
      Supabase.instance.client.removeChannel(sessionsChannel);
    }
    final RealtimeChannel? componentsChannel = _componentsRealtimeChannel;
    if (componentsChannel != null) {
      Supabase.instance.client.removeChannel(componentsChannel);
    }
    _repository.academicDataVersion.removeListener(_handleAcademicDataChanged);
    super.dispose();
  }

  void _handleAcademicDataChanged() {
    _refreshAcademicData();
  }

  void _refreshAcademicData() {
    if (!mounted) {
      return;
    }
    setState(() {
      _gradesDataFuture = _loadGradesData();
    });
  }

  void _subscribeToSubjectsRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('note-subjects-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subjects',
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
              _gradesDataFuture = _loadGradesData();
            });
          },
        )
        .subscribe();

    _subjectsRealtimeChannel = channel;
  }

  void _subscribeToSessionsRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('note-class-sessions-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'class_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            _refreshAcademicData();
          },
        )
        .subscribe();

    _sessionsRealtimeChannel = channel;
  }

  void _subscribeToComponentsRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('grade-components-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'grade_components',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            _refreshAcademicData();
          },
        )
        .subscribe();

    _componentsRealtimeChannel = channel;
  }

  Future<void> _reload() async {
    setState(() {
      _gradesDataFuture = _loadGradesData();
    });
    await _gradesDataFuture;
  }

  String _notesStorageKey() {
    final String userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    return 'note_type_grades_$userId';
  }

  Future<_GradesData> _loadGradesData() async {
    final List<AcademicSubjectV2> subjects = await _repository
        .fetchSubjectsV2();
    final List<ClassSession> sessions = await _repository
        .fetchClassSessionsV2();
    final List<GradeComponentRecord> components = await _repository
        .fetchGradeComponentsV2();
    return _GradesData(
      subjects: subjects,
      sessions: sessions,
      components: components,
    );
  }

  GradeComponentType _componentTypeFromRecordType(
    GradeComponentRecordType type,
  ) {
    return switch (type) {
      GradeComponentRecordType.exam => GradeComponentType.exam,
      GradeComponentRecordType.seminar => GradeComponentType.seminar,
      GradeComponentRecordType.laboratory => GradeComponentType.laboratory,
      GradeComponentRecordType.project => GradeComponentType.project,
      GradeComponentRecordType.coursework => GradeComponentType.coursework,
      GradeComponentRecordType.other => GradeComponentType.other,
    };
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

    final Map<String, double> gradesByLegacyKey = <String, double>{};
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
      final String componentName = parts[1].trim();
      final double? parsedValue = switch (value) {
        num numericValue => numericValue.toDouble(),
        String textValue => double.tryParse(textValue),
        _ => null,
      };

      if (subjectName.isEmpty || componentName.isEmpty) {
        return;
      }

      if (parsedValue == null || parsedValue < 1 || parsedValue > 10) {
        return;
      }

      gradesByLegacyKey['$subjectName|${canonicalGradeComponentName(componentName)}'] =
          parsedValue;
    });

    if (gradesByLegacyKey.isEmpty) {
      return;
    }

    try {
      final _GradesData data = await _loadGradesData();
      for (final AcademicSubjectV2 subject in data.subjects) {
        final List<GradeComponentRecord> components = _recordsForSubject(
          subject: subject,
          data: data,
        );
        for (final GradeComponentRecord component in components) {
          final double? grade =
              gradesByLegacyKey['${subject.name}|${component.name}'];
          if (grade == null) {
            continue;
          }
          await _repository.upsertGradeComponentV2(
            _componentWithGrade(component, grade),
          );
        }
      }
      await prefs.remove(_notesStorageKey());
      _refreshAcademicData();
    } catch (e) {
      debugPrint('Failed to migrate local grades: $e');
    }
  }

  AcademicSubjectV2 _findSubjectByName(_GradesData data, String subjectName) {
    final String normalized = subjectName.trim().toLowerCase();
    return data.subjects.firstWhere(
      (AcademicSubjectV2 subject) =>
          subject.name.trim().toLowerCase() == normalized,
      orElse: () => throw StateError('Subject not found.'),
    );
  }

  List<GradeComponentRecord> _recordsForSubject({
    required AcademicSubjectV2 subject,
    required _GradesData data,
  }) {
    final List<GradeComponentRecord> stored = data.components
        .where(
          (GradeComponentRecord component) => component.subjectId == subject.id,
        )
        .toList(growable: false);
    final Map<String, GradeComponentRecord> byName =
        <String, GradeComponentRecord>{
          for (final GradeComponentRecord component in stored)
            component.name: component,
        };

    byName.putIfAbsent(
      defaultGradeComponentName,
      () => _defaultComponent(
        subjectId: subject.id,
        componentName: defaultGradeComponentName,
      ),
    );

    for (final ClassSession session in data.sessions.where(
      (ClassSession session) => session.subjectId == subject.id,
    )) {
      final String componentName = canonicalGradeComponentName(
        session.sessionType,
      );
      if (componentName == fallbackGradeComponentName) {
        continue;
      }
      byName.putIfAbsent(
        componentName,
        () => _defaultComponent(
          subjectId: subject.id,
          componentName: componentName,
        ),
      );
    }

    return byName.values.toList(growable: false)
      ..sort((GradeComponentRecord a, GradeComponentRecord b) {
        final int aIndex = gradeComponentLabels.indexOf(a.name);
        final int bIndex = gradeComponentLabels.indexOf(b.name);
        final int normalizedA = aIndex == -1
            ? gradeComponentLabels.length
            : aIndex;
        final int normalizedB = bIndex == -1
            ? gradeComponentLabels.length
            : bIndex;
        return normalizedA.compareTo(normalizedB);
      });
  }

  GradeComponentRecord _recordForComponentName({
    required AcademicSubjectV2 subject,
    required _GradesData data,
    required String componentName,
  }) {
    final String normalized = canonicalGradeComponentName(componentName);
    return _recordsForSubject(subject: subject, data: data).firstWhere(
      (GradeComponentRecord component) => component.name == normalized,
      orElse: () =>
          _defaultComponent(subjectId: subject.id, componentName: normalized),
    );
  }

  GradeComponentRecord _defaultComponent({
    required String subjectId,
    required String componentName,
  }) {
    return GradeComponentRecord(
      id: '',
      subjectId: subjectId,
      name: componentName,
      type: gradeComponentRecordTypeFromLabel(componentName),
      weightPercent: 0,
      minimumGrade: 5,
      grade: null,
      isRequired: true,
      isEliminatory: isEliminatoryGradeComponent(componentName),
    );
  }

  GradeComponentRecord _componentWithGrade(
    GradeComponentRecord component,
    double? grade,
  ) {
    return GradeComponentRecord(
      id: component.id,
      subjectId: component.subjectId,
      name: component.name,
      type: component.type,
      weightPercent: component.weightPercent,
      minimumGrade: component.minimumGrade,
      grade: grade,
      isRequired: component.isRequired,
      isEliminatory: component.isEliminatory,
    );
  }

  GradeComponentRecord _componentWithWeight(
    GradeComponentRecord component,
    double weightPercent,
  ) {
    return GradeComponentRecord(
      id: component.id,
      subjectId: component.subjectId,
      name: component.name,
      type: component.type,
      weightPercent: weightPercent,
      minimumGrade: component.minimumGrade,
      grade: component.grade,
      isRequired: component.isRequired,
      isEliminatory: component.isEliminatory,
    );
  }

  Future<void> _saveComponentGrade({
    required String subjectName,
    required String componentName,
    required double? value,
  }) async {
    try {
      final _GradesData data = await _gradesDataFuture;
      final AcademicSubjectV2 subject = _findSubjectByName(data, subjectName);
      final GradeComponentRecord component = _recordForComponentName(
        subject: subject,
        data: data,
        componentName: componentName,
      );
      await _repository.upsertGradeComponentV2(
        _componentWithGrade(component, value),
      );
      _refreshAcademicData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-a putut salva nota.')),
        );
      }
    }
  }

  Future<void> _saveComponentWeights({
    required String subjectName,
    required Map<String, double> weightsByComponent,
  }) async {
    try {
      final _GradesData data = await _gradesDataFuture;
      final AcademicSubjectV2 subject = _findSubjectByName(data, subjectName);
      for (final String componentName in _activeWeightedComponents(
        subjectName: subjectName,
        data: data,
      )) {
        final GradeComponentRecord component = _recordForComponentName(
          subject: subject,
          data: data,
          componentName: componentName,
        );
        await _repository.upsertGradeComponentV2(
          _componentWithWeight(
            component,
            weightsByComponent[componentName] ?? 0,
          ),
        );
      }
      _refreshAcademicData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-au putut salva ponderile.')),
        );
      }
    }
  }

  Future<void> _resetComponentWeights(String subjectName) async {
    await _saveComponentWeights(
      subjectName: subjectName,
      weightsByComponent: <String, double>{},
    );
  }

  Future<void> _openComponentGradeDialog(
    String subjectName,
    String componentName,
  ) async {
    final _GradesData data;
    try {
      data = await _gradesDataFuture;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-au putut incarca notele.')),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }

    final AcademicSubjectV2 subject = _findSubjectByName(data, subjectName);
    final GradeComponentRecord component = _recordForComponentName(
      subject: subject,
      data: data,
      componentName: componentName,
    );
    final double? existing = component.grade;

    final _ComponentGradeDialogResult? result =
        await showDialog<_ComponentGradeDialogResult>(
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
                      title: Text('$subjectName - $componentName'),
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
                              ).pop(const _ComponentGradeDialogResult.delete());
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
                              _ComponentGradeDialogResult.save(
                                parsed.toDouble(),
                              ),
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

    await _saveComponentGrade(
      subjectName: subjectName,
      componentName: componentName,
      value: result.delete ? null : result.value,
    );
  }

  Future<void> _openComponentWeightDialog(String subjectName) async {
    final _GradesData data;
    try {
      data = await _gradesDataFuture;
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

    final AcademicSubjectV2 subject = _findSubjectByName(data, subjectName);
    final List<String> activeWeightedComponents = _activeWeightedComponents(
      subjectName: subjectName,
      data: data,
    );
    final Map<String, double?> existing = <String, double?>{};
    for (final String componentName in activeWeightedComponents) {
      existing[componentName] = _recordForComponentName(
        subject: subject,
        data: data,
        componentName: componentName,
      ).weightPercent;
    }

    final Map<String, TextEditingController> controllers =
        <String, TextEditingController>{
          for (final String componentName in activeWeightedComponents)
            componentName: TextEditingController(
              text: existing[componentName]?.toString() ?? '',
            ),
        };

    final _ComponentWeightDialogResult?
    result = await showDialog<_ComponentWeightDialogResult>(
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
                      ...activeWeightedComponents.map(
                        (String componentName) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: controllers[componentName],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '$componentName (%)',
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
                          ).pop(const _ComponentWeightDialogResult.delete());
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

                        for (final String componentName
                            in activeWeightedComponents) {
                          final double value = parseValue(
                            controllers[componentName]?.text ?? '',
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
                            parsed[componentName] = value;
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
                        ).pop(_ComponentWeightDialogResult.save(parsed));
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
      await _resetComponentWeights(subjectName);
      return;
    }

    await _saveComponentWeights(
      subjectName: subjectName,
      weightsByComponent: result.weightsByComponent,
    );
  }

  List<String> _activeWeightedComponents({
    required String subjectName,
    required _GradesData data,
  }) {
    final AcademicSubjectV2 subject = _findSubjectByName(data, subjectName);
    final Set<String> activeComponents =
        _recordsForSubject(subject: subject, data: data)
            .map((GradeComponentRecord component) => component.name)
            .where(weightedGradeComponentLabels.contains)
            .toSet();

    if (activeComponents.isEmpty) {
      activeComponents.add(defaultGradeComponentName);
    }

    return weightedGradeComponentLabels
        .where(activeComponents.contains)
        .toList(growable: false);
  }

  AcademicSubject _buildAcademicSubject({
    required AcademicSubjectV2 subject,
    required _GradesData data,
  }) {
    final List<GradeComponentRecord> records = _recordsForSubject(
      subject: subject,
      data: data,
    );

    final bool hasConfiguredWeights = records.any(
      (GradeComponentRecord component) => component.weightPercent > 0,
    );
    final double defaultWeight = records.isEmpty ? 0 : 1 / records.length;

    final List<GradeComponent> components =
        records
            .map((GradeComponentRecord record) {
              return GradeComponent(
                id: record.id.isEmpty
                    ? '${subject.id}|${record.name}'
                    : record.id,
                name: record.name,
                type: _componentTypeFromRecordType(record.type),
                grade: record.grade,
                weight: hasConfiguredWeights
                    ? record.weightPercent / 100
                    : defaultWeight,
                minGrade: record.minimumGrade,
                isRequired: record.isRequired,
                isEliminatory: record.isEliminatory,
              );
            })
            .toList(growable: false)
          ..sort((GradeComponent a, GradeComponent b) {
            final int aIndex = gradeComponentLabels.indexOf(a.name);
            final int bIndex = gradeComponentLabels.indexOf(b.name);
            final int normalizedA = aIndex == -1
                ? gradeComponentLabels.length
                : aIndex;
            final int normalizedB = bIndex == -1
                ? gradeComponentLabels.length
                : bIndex;
            return normalizedA.compareTo(normalizedB);
          });

    return AcademicSubject(
      id: subject.id,
      name: subject.name,
      semester: subject.semesterLabel,
      year: 0,
      credits: subject.credits,
      components: components,
    );
  }

  List<SubjectNoteCardData> _buildSubjectCards({
    required _GradesData data,
    String? selectedSemester,
  }) {
    final List<AcademicSubjectV2> subjects =
        List<AcademicSubjectV2>.of(data.subjects)..sort(
          (AcademicSubjectV2 a, AcademicSubjectV2 b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    final List<SubjectNoteCardData> cards = <SubjectNoteCardData>[];

    for (final AcademicSubjectV2 subjectModel in subjects) {
      final String subjectName = subjectModel.name;
      if (selectedSemester != null &&
          subjectModel.semesterLabel != selectedSemester) {
        continue;
      }

      final AcademicSubject subject = _buildAcademicSubject(
        subject: subjectModel,
        data: data,
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

  List<SemesterAverageData> _semesterAverages(List<SubjectNoteCardData> cards) {
    return UniHubRepository.availableSemesters
        .map((String semesterLabel) {
          final List<SubjectNoteCardData> semesterCards = cards
              .where(
                (SubjectNoteCardData card) =>
                    card.evaluation.subject.semester == semesterLabel,
              )
              .toList(growable: false);

          return SemesterAverageData(
            semesterLabel: semesterLabel,
            totalCredits: _totalCredits(semesterCards),
            earnedCredits: _earnedCredits(semesterCards),
            average: _weightedAverage(semesterCards),
          );
        })
        .toList(growable: false);
  }

  void _changeSelectedSemester(String semester) {
    if (semester == _selectedSemester) {
      return;
    }

    setState(() {
      _selectedSemester = semester;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GradesData>(
      future: _gradesDataFuture,
      builder: (BuildContext context, AsyncSnapshot<_GradesData> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return GradesLoadError(onRetry: _reload);
        }

        final _GradesData data =
            snapshot.data ??
            const _GradesData(
              subjects: <AcademicSubjectV2>[],
              sessions: <ClassSession>[],
              components: <GradeComponentRecord>[],
            );
        final List<String> semesterOptions =
            UniHubRepository.availableSemesters;
        final String selectedSemester =
            semesterOptions.contains(_selectedSemester)
            ? _selectedSemester
            : semesterOptions.first;
        final List<SubjectNoteCardData> allSubjectCards = _buildSubjectCards(
          data: data,
        );
        final List<SubjectNoteCardData> subjectCards = _buildSubjectCards(
          data: data,
          selectedSemester: selectedSemester,
        );

        return GradesScreenView(
          subjectCards: subjectCards,
          totalCredits: _totalCredits(allSubjectCards),
          earnedCredits: _earnedCredits(allSubjectCards),
          weightedAverage: _weightedAverage(allSubjectCards),
          semesterAverages: _semesterAverages(allSubjectCards),
          onRefresh: _reload,
          selectedSemester: selectedSemester,
          semesterOptions: semesterOptions,
          onSemesterChanged: _changeSelectedSemester,
          totalSubjectsCount: subjectCards.length,
          onEditComponentGrade: _openComponentGradeDialog,
          onEditComponentWeights: _openComponentWeightDialog,
          onResetComponentWeights: _resetComponentWeights,
        );
      },
    );
  }
}

class _ComponentGradeDialogResult {
  const _ComponentGradeDialogResult.save(this.value) : delete = false;
  const _ComponentGradeDialogResult.delete() : value = null, delete = true;

  final double? value;
  final bool delete;
}

class _ComponentWeightDialogResult {
  const _ComponentWeightDialogResult.save(this.weightsByComponent)
    : delete = false;
  const _ComponentWeightDialogResult.delete()
    : weightsByComponent = const <String, double>{},
      delete = true;

  final Map<String, double> weightsByComponent;
  final bool delete;
}

class _GradesData {
  const _GradesData({
    required this.subjects,
    required this.sessions,
    required this.components,
  });

  final List<AcademicSubjectV2> subjects;
  final List<ClassSession> sessions;
  final List<GradeComponentRecord> components;
}
