import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/data/schedule_visibility_store.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/screens/ui/calendar_screen_view.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  final ScheduleVisibilityStore _visibilityStore =
      ScheduleVisibilityStore.instance;
  static const List<String> _weekdayOptions = <String>[
    'Luni',
    'Marti',
    'Miercuri',
    'Joi',
    'Vineri',
    'Sambata',
    'Duminica',
  ];
  static const List<String> _courseTypeOptions = <String>[
    'Curs',
    'Seminar',
    'Laborator',
  ];

  String _selectedSemester = 'Semestrul 2';
  late Future<List<Course>> _coursesFuture;
  bool _isAddingCourse = false;
  bool _isDeletingCourse = false;
  bool _isDeletingCourseType = false;
  bool _isEditingCourseType = false;
  bool _isUpdatingSemesterVisibility = false;
  Set<String> _hiddenScheduleSemesters = <String>{};
  RealtimeChannel? _coursesRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _coursesFuture = _loadCoursesForSemester(_selectedSemester);
    unawaited(_loadScheduleVisibility());
    _subscribeToCoursesRealtime();
  }

  @override
  void dispose() {
    final RealtimeChannel? channel = _coursesRealtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToCoursesRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('materii-courses-user-${user.id}')
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
              _coursesFuture = _loadCoursesForSemester(_selectedSemester);
            });
          },
        )
        .subscribe();

    _coursesRealtimeChannel = channel;
  }

  Future<List<Course>> _loadCoursesForSemester(String semesterLabel) async {
    final List<Course> courses = await _repository.fetchCourses(
      semesterLabel: semesterLabel,
    );
    return courses;
  }

  Future<void> _loadScheduleVisibility() async {
    final Set<String> hiddenSemesters = await _visibilityStore
        .fetchHiddenSemesters();
    if (!mounted) {
      return;
    }
    setState(() {
      _hiddenScheduleSemesters = hiddenSemesters;
    });
  }

  Future<void> _setSelectedSemesterScheduleVisibility(bool isVisible) async {
    if (_isUpdatingSemesterVisibility) {
      return;
    }

    setState(() {
      _isUpdatingSemesterVisibility = true;
    });

    try {
      await _visibilityStore.setSemesterVisible(
        semesterLabel: _selectedSemester,
        isVisible: isVisible,
      );
      await _loadScheduleVisibility();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVisible
                ? '$_selectedSemester apare din nou in Orar.'
                : '$_selectedSemester a fost ascuns din Orar.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am putut actualiza vizibilitatea in Orar.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingSemesterVisibility = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _coursesFuture = _loadCoursesForSemester(_selectedSemester);
    });
    await _coursesFuture;
  }

  Future<void> _changeSemester(String semesterLabel) async {
    if (semesterLabel == _selectedSemester) {
      return;
    }

    setState(() {
      _selectedSemester = semesterLabel;
      _coursesFuture = _loadCoursesForSemester(_selectedSemester);
    });
  }

  int _sortOrderFromTime(String value) {
    final RegExpMatch? match = RegExp(
      r'(\d{1,2})\s*:\s*(\d{2})',
    ).firstMatch(value);
    if (match == null) {
      return 0;
    }

    final int hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final int minute = int.tryParse(match.group(2) ?? '') ?? 0;
    return (hour * 60) + minute;
  }

  bool _isPendingCourse(Course course) {
    return course.time == UniHubRepository.pendingCourseTimeLabel;
  }

  Future<bool> _subjectExistsForSemester({
    required String subjectName,
    required String semesterLabel,
  }) async {
    final List<Course> courses = await _repository.fetchCourses(
      semesterLabel: semesterLabel,
    );
    final String normalizedName = subjectName.trim().toLowerCase();

    return courses.any(
      (Course course) => course.name.trim().toLowerCase() == normalizedName,
    );
  }

  Future<void> _openAddCourseDialog() async {
    if (_isAddingCourse) {
      return;
    }

    final _SubjectDraft? newSubject = await showDialog<_SubjectDraft>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddSubjectDialog(
          initialSemester: _selectedSemester,
          semesterOptions: UniHubRepository.availableSemesters,
        );
      },
    );

    if (!mounted || newSubject == null) {
      return;
    }

    setState(() {
      _isAddingCourse = true;
    });

    try {
      final bool subjectExists = await _subjectExistsForSemester(
        subjectName: newSubject.name,
        semesterLabel: newSubject.semesterLabel,
      );

      if (subjectExists) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Materia exista deja in semestrul selectat.'),
          ),
        );
        return;
      }

      await _repository.addCourseSubject(
        subjectName: newSubject.name,
        semesterLabel: newSubject.semesterLabel,
        credits: newSubject.credits,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSemester = newSubject.semesterLabel;
        _coursesFuture = _loadCoursesForSemester(_selectedSemester);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Materia a fost adaugata. Apasa cardul pentru detalii.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am putut adauga cursul. Incearca din nou.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingCourse = false;
        });
      }
    }
  }

  Future<void> _openAddDetailsDialog(String subjectName) async {
    final List<Course> semesterCourses = await _repository.fetchCourses(
      semesterLabel: _selectedSemester,
    );
    Course? subjectReference;
    for (final Course course in semesterCourses) {
      if (course.name == subjectName) {
        subjectReference = course;
        break;
      }
    }

    final Course? detailedCourse = await showDialog<Course>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddCourseDetailsDialog(
          subjectName: subjectName,
          semesterLabel: _selectedSemester,
          subjectCredits: subjectReference?.credits ?? 5,
          weekdayOptions: _weekdayOptions,
          courseTypeOptions: _courseTypeOptions,
          sortOrderFromTime: _sortOrderFromTime,
        );
      },
    );

    if (!mounted || detailedCourse == null) {
      return;
    }

    try {
      await _repository.addUserCourse(detailedCourse);
      await _repository.clearPendingCourseDraft(
        subjectName: subjectName,
        semesterLabel: _selectedSemester,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _coursesFuture = _loadCoursesForSemester(_selectedSemester);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detaliile au fost adaugate.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut salva detaliile.')),
      );
    }
  }

  Future<void> _openDeleteCourseDialog() async {
    if (_isDeletingCourse) {
      return;
    }

    final List<Course> semesterCourses = await _repository.fetchCourses(
      semesterLabel: _selectedSemester,
    );

    final List<String> subjects =
        semesterCourses
            .map((Course course) => course.name.trim())
            .where((String name) => name.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort(
            (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
          );

    if (!mounted) {
      return;
    }

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu exista materii de sters in acest semestru.'),
        ),
      );
      return;
    }

    final String? subjectToDelete = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _DeleteSubjectDialog(subjects: subjects);
      },
    );

    if (!mounted || subjectToDelete == null) {
      return;
    }

    setState(() {
      _isDeletingCourse = true;
    });

    try {
      final int deletedCount = await _repository.deleteSubjectCourses(
        subjectName: subjectToDelete,
        semesterLabel: _selectedSemester,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _coursesFuture = _loadCoursesForSemester(_selectedSemester);
      });

      if (deletedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Materia $subjectToDelete a fost stearsa.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nu am gasit in tabela materia selectata.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am putut sterge materia. Incearca din nou.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingCourse = false;
        });
      }
    }
  }

  Future<void> _deleteCourseType(String subjectName, Course course) async {
    if (_isDeletingCourseType) {
      return;
    }

    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Sterge tipul de curs'),
              content: Text(
                'Stergi ${course.courseType} (${course.weekdayLabel}, ${course.time}) de la materia $subjectName?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Renunta'),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Sterge'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted || !shouldDelete) {
      return;
    }

    setState(() {
      _isDeletingCourseType = true;
    });

    try {
      final int deletedCount = await _repository.deleteCourseTypeEntry(
        course: course,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _coursesFuture = _loadCoursesForSemester(_selectedSemester);
      });

      if (deletedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tipul de curs a fost sters din tabela.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nu am gasit in tabela acest tip de curs.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut sterge tipul de curs.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingCourseType = false;
        });
      }
    }
  }

  Future<void> _editCourseType(String subjectName, Course course) async {
    if (_isEditingCourseType) {
      return;
    }

    final Course? updatedCourse = await showDialog<Course>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddCourseDetailsDialog(
          subjectName: subjectName,
          semesterLabel: _selectedSemester,
          subjectCredits: course.credits,
          weekdayOptions: _weekdayOptions,
          courseTypeOptions: _courseTypeOptions,
          sortOrderFromTime: _sortOrderFromTime,
          initialCourse: course,
          submitButtonLabel: 'Salveaza modificarile',
        );
      },
    );

    if (!mounted || updatedCourse == null) {
      return;
    }

    setState(() {
      _isEditingCourseType = true;
    });

    try {
      final int updatedCount = await _repository.updateCourseTypeEntry(
        originalCourse: course,
        updatedCourse: updatedCourse,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _coursesFuture = _loadCoursesForSemester(_selectedSemester);
      });

      if (updatedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipul de curs a fost actualizat.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nu am gasit in tabela cursul selectat pentru editare.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut actualiza tipul de curs.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEditingCourseType = false;
        });
      }
    }
  }

  int _courseTypeOrder(String courseType) {
    return switch (courseType) {
      'Curs' => 0,
      'Seminar' => 1,
      'Laborator' => 2,
      _ => 99,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Course>>(
      future: _coursesFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
        final List<Course> courses = snapshot.data ?? <Course>[];
        final Map<String, List<Course>> groupedCourses =
            <String, List<Course>>{};

        for (final Course course in courses) {
          groupedCourses.putIfAbsent(course.name, () => <Course>[]).add(course);
        }

        for (final List<Course> subjectCourses in groupedCourses.values) {
          subjectCourses.sort((Course a, Course b) {
            final bool aPending = _isPendingCourse(a);
            final bool bPending = _isPendingCourse(b);
            if (aPending != bPending) {
              return aPending ? 1 : -1;
            }

            if (a.sortOrder != b.sortOrder) {
              return a.sortOrder.compareTo(b.sortOrder);
            }
            return _courseTypeOrder(
              a.courseType,
            ).compareTo(_courseTypeOrder(b.courseType));
          });
        }

        return CalendarScreenView(
          selectedSemester: _selectedSemester,
          isSelectedSemesterVisibleInSchedule: !_hiddenScheduleSemesters
              .contains(_selectedSemester),
          isUpdatingSemesterVisibility: _isUpdatingSemesterVisibility,
          onSemesterChanged: _changeSemester,
          onScheduleVisibilityChanged: _setSelectedSemesterScheduleVisibility,
          onAddCourse: _openAddCourseDialog,
          onDeleteCourse: _openDeleteCourseDialog,
          onSubjectTap: _openAddDetailsDialog,
          onEditCourseType: _editCourseType,
          onDeleteCourseType: _deleteCourseType,
          isAddingCourse: _isAddingCourse,
          isDeletingCourse: _isDeletingCourse,
          isEditingCourseType: _isEditingCourseType,
          isDeletingCourseType: _isDeletingCourseType,
          pendingTimeLabel: UniHubRepository.pendingCourseTimeLabel,
          onRefresh: _reload,
          connectionState: snapshot.connectionState,
          hasError: snapshot.hasError,
          subjectEntries: groupedCourses.entries.toList(growable: false),
          onRetry: _reload,
        );
      },
    );
  }
}

class _SubjectDraft {
  const _SubjectDraft({
    required this.name,
    required this.semesterLabel,
    required this.credits,
  });

  final String name;
  final String semesterLabel;
  final int credits;
}

class _AddSubjectDialog extends StatefulWidget {
  const _AddSubjectDialog({
    required this.initialSemester,
    required this.semesterOptions,
  });

  final String initialSemester;
  final List<String> semesterOptions;

  @override
  State<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<_AddSubjectDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _creditsController = TextEditingController(
    text: '5',
  );

  late String _selectedSemester;

  @override
  void initState() {
    super.initState();
    _selectedSemester = widget.initialSemester;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final _SubjectDraft draft = _SubjectDraft(
      name: _nameController.text.trim(),
      semesterLabel: _selectedSemester,
      credits: int.parse(_creditsController.text.trim()),
    );

    Navigator.of(context).pop<_SubjectDraft>(draft);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adauga materie'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Materie'),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Introdu numele materiei';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSemester,
                  decoration: const InputDecoration(labelText: 'Semestru'),
                  items: widget.semesterOptions
                      .map(
                        (String semester) => DropdownMenuItem<String>(
                          value: semester,
                          child: Text(semester),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedSemester = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _creditsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Credite (1-60)',
                  ),
                  validator: (String? value) {
                    final int? credits = int.tryParse((value ?? '').trim());
                    if (credits == null) {
                      return 'Introdu un numar valid';
                    }
                    if (credits <= 0 || credits > 60) {
                      return 'Creditele trebuie sa fie intre 1 si 60';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunta'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Adauga')),
      ],
    );
  }
}

class _AddCourseDetailsDialog extends StatefulWidget {
  const _AddCourseDetailsDialog({
    required this.subjectName,
    required this.semesterLabel,
    required this.subjectCredits,
    required this.weekdayOptions,
    required this.courseTypeOptions,
    required this.sortOrderFromTime,
    this.initialCourse,
    this.submitButtonLabel = 'Salveaza',
  });

  final String subjectName;
  final String semesterLabel;
  final int subjectCredits;
  final List<String> weekdayOptions;
  final List<String> courseTypeOptions;
  final int Function(String value) sortOrderFromTime;
  final Course? initialCourse;
  final String submitButtonLabel;

  @override
  State<_AddCourseDetailsDialog> createState() =>
      _AddCourseDetailsDialogState();
}

class _AddCourseDetailsDialogState extends State<_AddCourseDetailsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _professorController = TextEditingController();

  late String _selectedWeekday;
  late String _selectedCourseType;

  @override
  void initState() {
    super.initState();
    final Course? initialCourse = widget.initialCourse;
    _selectedWeekday =
        initialCourse?.weekdayLabel ?? widget.weekdayOptions.first;
    _selectedCourseType =
        initialCourse?.courseType ?? widget.courseTypeOptions.first;
    _roomController.text = initialCourse?.room ?? '';
    _professorController.text = initialCourse?.professor ?? '';

    final RegExpMatch? timeMatch = RegExp(
      r'^(\d{1,2})\s*:\s*(\d{2})\s*-\s*(\d{1,2})\s*:\s*(\d{2})$',
    ).firstMatch((initialCourse?.time ?? '').trim());
    if (timeMatch != null) {
      final int? startHour = int.tryParse(timeMatch.group(1) ?? '');
      final int? startMinute = int.tryParse(timeMatch.group(2) ?? '');
      final int? endHour = int.tryParse(timeMatch.group(3) ?? '');
      final int? endMinute = int.tryParse(timeMatch.group(4) ?? '');
      if (startHour != null &&
          startMinute != null &&
          endHour != null &&
          endMinute != null) {
        _startTimeController.text = _formatMinutes(
          startHour * 60 + startMinute,
        );
        _endTimeController.text = _formatMinutes(endHour * 60 + endMinute);
      }
    }

    if (_startTimeController.text.trim().isEmpty) {
      _startTimeController.text = '08:00';
    }
    if (_endTimeController.text.trim().isEmpty) {
      _endTimeController.text = '09:00';
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _professorController.dispose();
    super.dispose();
  }

  int? _parseTimeToMinutes(String value) {
    final String text = value.trim();
    final RegExpMatch? match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text);
    if (match == null) {
      return null;
    }

    final int? hour = int.tryParse(match.group(1) ?? '');
    final int? minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return (hour * 60) + minute;
  }

  String _formatMinutes(int totalMinutes) {
    final int normalized = totalMinutes.clamp(0, 1439);
    final int hour = normalized ~/ 60;
    final int minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<int?> _openTimeWheelPicker({
    required int initialMinutes,
    required String title,
    int minimumMinutes = 0,
  }) async {
    final int normalizedMinimum = minimumMinutes.clamp(0, 1439);
    final int clampedInitial = initialMinutes.clamp(normalizedMinimum, 1439);

    int selectedHour = clampedInitial ~/ 60;
    int selectedMinute = clampedInitial % 60;

    final int minimumHour = normalizedMinimum ~/ 60;
    final int minimumMinute = normalizedMinimum % 60;
    final List<int> hourOptions = List<int>.generate(
      24 - minimumHour,
      (int index) => minimumHour + index,
    );

    bool canConfirm() {
      final int selectedTotal = (selectedHour * 60) + selectedMinute;
      return selectedTotal >= normalizedMinimum;
    }

    return showCupertinoModalPopup<int>(
      context: context,
      builder: (BuildContext popupContext) {
        final FixedExtentScrollController hourController =
            FixedExtentScrollController(
              initialItem: hourOptions.indexOf(selectedHour),
            );
        final FixedExtentScrollController minuteController =
            FixedExtentScrollController(initialItem: selectedMinute);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: 340,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: 50,
                      child: Row(
                        children: <Widget>[
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: () => Navigator.of(popupContext).pop(),
                            child: const Text('Renunta'),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: canConfirm()
                                ? () => Navigator.of(
                                    popupContext,
                                  ).pop((selectedHour * 60) + selectedMinute)
                                : null,
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: hourController,
                              itemExtent: 38,
                              onSelectedItemChanged: (int index) {
                                setModalState(() {
                                  selectedHour = hourOptions[index];
                                });
                              },
                              children: hourOptions
                                  .map(
                                    (int hour) => Center(
                                      child: Text(
                                        hour.toString().padLeft(2, '0'),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(':', style: TextStyle(fontSize: 22)),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: minuteController,
                              itemExtent: 38,
                              onSelectedItemChanged: (int minute) {
                                setModalState(() {
                                  selectedMinute = minute;
                                });
                              },
                              children: List<Widget>.generate(60, (int minute) {
                                return Center(
                                  child: Text(
                                    minute.toString().padLeft(2, '0'),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (normalizedMinimum > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Text(
                          'Ora sfarsit trebuie sa fie dupa ${minimumHour.toString().padLeft(2, '0')}:${minimumMinute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickStartHour() async {
    final int initialMinutes =
        _parseTimeToMinutes(_startTimeController.text) ?? (8 * 60);

    final int? selectedMinutes = await _openTimeWheelPicker(
      initialMinutes: initialMinutes,
      title: 'Alege ora de inceput',
    );
    if (selectedMinutes == null || !mounted) {
      return;
    }

    final int currentEnd =
        _parseTimeToMinutes(_endTimeController.text) ?? (selectedMinutes + 60);
    final int minimumEnd = selectedMinutes + 1;

    setState(() {
      _startTimeController.text = _formatMinutes(selectedMinutes);
      if (currentEnd <= selectedMinutes) {
        _endTimeController.text = _formatMinutes(
          minimumEnd > 1439 ? 1439 : minimumEnd,
        );
      }
    });
  }

  Future<void> _pickEndHour() async {
    final int startMinutes =
        _parseTimeToMinutes(_startTimeController.text) ?? 0;
    final int minimumEnd = startMinutes + 1;
    if (minimumEnd > 1439) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ora de inceput este prea tarzie. Alege o ora de inceput mai devreme.',
          ),
        ),
      );
      return;
    }

    final int initialMinutesRaw =
        _parseTimeToMinutes(_endTimeController.text) ?? minimumEnd;
    final int initialMinutes = initialMinutesRaw < minimumEnd
        ? minimumEnd
        : initialMinutesRaw;

    final int? selectedMinutes = await _openTimeWheelPicker(
      initialMinutes: initialMinutes,
      title: 'Alege ora de final',
      minimumMinutes: minimumEnd,
    );
    if (selectedMinutes == null || !mounted) {
      return;
    }

    setState(() {
      _endTimeController.text = _formatMinutes(selectedMinutes);
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final int? startMinutes = _parseTimeToMinutes(_startTimeController.text);
    final int? endMinutes = _parseTimeToMinutes(_endTimeController.text);
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return;
    }

    final String intervalLabel =
        '${_formatMinutes(startMinutes)} - ${_formatMinutes(endMinutes)}';

    final Course course = Course(
      name: widget.subjectName,
      semesterLabel: widget.semesterLabel,
      credits: widget.initialCourse?.credits ?? widget.subjectCredits,
      courseType: _selectedCourseType,
      weekdayLabel: _selectedWeekday,
      time: intervalLabel,
      room: _roomController.text.trim(),
      professor: _professorController.text.trim(),
      sortOrder: widget.sortOrderFromTime(intervalLabel),
    );

    Navigator.of(context).pop<Course>(course);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adauga detalii curs'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.subjectName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Credite: ${widget.subjectCredits}'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCourseType,
                  decoration: const InputDecoration(labelText: 'Tip curs'),
                  items: widget.courseTypeOptions
                      .map(
                        (String type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCourseType = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedWeekday,
                  decoration: const InputDecoration(labelText: 'Ziua'),
                  items: widget.weekdayOptions
                      .map(
                        (String day) => DropdownMenuItem<String>(
                          value: day,
                          child: Text(day),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedWeekday = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _roomController,
                  decoration: const InputDecoration(labelText: 'Sala'),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Introdu sala';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _startTimeController,
                        readOnly: true,
                        onTap: _pickStartHour,
                        decoration: const InputDecoration(
                          labelText: 'Ora inceput',
                          hintText: '08:00',
                          suffixIcon: Icon(Icons.access_time_rounded),
                        ),
                        validator: (String? value) {
                          final int? minutes = _parseTimeToMinutes(value ?? '');
                          if ((value ?? '').trim().isEmpty) {
                            return 'Obligatoriu';
                          }
                          if (minutes == null) {
                            return 'Alege ora';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _endTimeController,
                        readOnly: true,
                        onTap: _pickEndHour,
                        decoration: const InputDecoration(
                          labelText: 'Ora sfarsit',
                          hintText: '09:00',
                          suffixIcon: Icon(Icons.access_time_rounded),
                        ),
                        validator: (String? value) {
                          final int? endMinutes = _parseTimeToMinutes(
                            value ?? '',
                          );
                          final int? startMinutes = _parseTimeToMinutes(
                            _startTimeController.text,
                          );
                          if ((value ?? '').trim().isEmpty) {
                            return 'Obligatoriu';
                          }
                          if (endMinutes == null) {
                            return 'Alege ora';
                          }
                          if (startMinutes != null &&
                              endMinutes <= startMinutes) {
                            return 'Dupa inceput';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _professorController,
                  decoration: const InputDecoration(labelText: 'Profesor'),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Introdu numele profesorului';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunta'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitButtonLabel)),
      ],
    );
  }
}

class _DeleteSubjectDialog extends StatefulWidget {
  const _DeleteSubjectDialog({required this.subjects});

  final List<String> subjects;

  @override
  State<_DeleteSubjectDialog> createState() => _DeleteSubjectDialogState();
}

class _DeleteSubjectDialogState extends State<_DeleteSubjectDialog> {
  late String _selectedSubject;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.subjects.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sterge materie'),
      content: DropdownButtonFormField<String>(
        initialValue: _selectedSubject,
        decoration: const InputDecoration(labelText: 'Materie'),
        items: widget.subjects
            .map(
              (String subject) => DropdownMenuItem<String>(
                value: subject,
                child: Text(subject),
              ),
            )
            .toList(growable: false),
        onChanged: (String? value) {
          if (value == null) {
            return;
          }
          setState(() {
            _selectedSubject = value;
          });
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Renunta'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(_selectedSubject),
          child: const Text('Sterge'),
        ),
      ],
    );
  }
}
