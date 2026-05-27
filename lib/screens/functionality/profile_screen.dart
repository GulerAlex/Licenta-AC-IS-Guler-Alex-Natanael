import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unihub/data/app_preferences_store.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/grade_component_record.dart';
import 'package:unihub/models/profile_stats.dart';
import 'package:unihub/models/user_profile.dart';
import 'package:unihub/screens/ui/profile_screen_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onLogout,
    required this.themePreference,
    required this.avatarColor,
    required this.onThemePreferenceChanged,
    required this.onAvatarColorChanged,
  });

  final Future<void> Function() onLogout;
  final AppThemePreference themePreference;
  final Color avatarColor;
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;
  final ValueChanged<Color> onAvatarColorChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  late Future<UserProfile> _profileFuture;
  late Future<ProfileStats> _statsFuture;
  late Future<Map<String, ProfileStats>> _semesterStatsFuture;
  bool _isLoggingOut = false;
  bool _isUpdatingProfile = false;
  bool _isUpdatingGroup = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repository.fetchProfile();
    _statsFuture = _repository.fetchProfileStats();
    _semesterStatsFuture = _fetchSemesterStats();
  }

  Future<void> _reload() async {
    final Future<UserProfile> profileFuture = _repository.fetchProfile();
    final Future<ProfileStats> statsFuture = _repository.fetchProfileStats();
    final Future<Map<String, ProfileStats>> semesterStatsFuture =
        _fetchSemesterStats();

    if (!mounted) {
      return;
    }

    setState(() {
      _profileFuture = profileFuture;
      _statsFuture = statsFuture;
      _semesterStatsFuture = semesterStatsFuture;
    });
    await Future.wait(<Future<dynamic>>[
      profileFuture,
      statsFuture,
      semesterStatsFuture,
    ]);
  }

  Future<Map<String, ProfileStats>> _fetchSemesterStats() async {
    final List<Future<MapEntry<String, ProfileStats>>> futures =
        UniHubRepository.availableSemesters
            .map((String semesterLabel) async {
              final ProfileStats stats = await _repository.fetchProfileStats(
                semesterLabel: semesterLabel,
              );
              return MapEntry<String, ProfileStats>(semesterLabel, stats);
            })
            .toList(growable: false);

    return Map<String, ProfileStats>.fromEntries(await Future.wait(futures));
  }

  void _showSnackBarAfterBuild(SnackBar snackBar) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    });
  }

  Future<void> _openEditProfileDialog(UserProfile profile) async {
    if (_isUpdatingProfile) {
      return;
    }

    final _ProfileEditDraft? draft = await showDialog<_ProfileEditDraft>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _ProfileEditDialog(profile: profile),
    );

    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _isUpdatingProfile = true;
    });

    try {
      await _repository.updateProfile(
        fullName: draft.fullName,
        faculty: draft.faculty,
        studyYear: draft.studyYear,
        universityEmail: draft.universityEmail,
      );
      if (mounted) {
        setState(() {
          _profileFuture = _repository.fetchProfile();
          _statsFuture = _repository.fetchProfileStats();
          _semesterStatsFuture = _fetchSemesterStats();
          _isUpdatingProfile = false;
        });
        _showSnackBarAfterBuild(
          const SnackBar(content: Text('Profilul a fost actualizat.')),
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnackBarAfterBuild(
          const SnackBar(content: Text('Nu am putut salva profilul.')),
        );
      }
    } finally {
      if (mounted && _isUpdatingProfile) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }

  Future<void> _openChangeGroupDialog(String? currentGroup) async {
    if (_isUpdatingGroup) {
      return;
    }

    final List<String> groups = UniHubRepository.availableGroups;
    String selectedGroup = groups.first;
    if (currentGroup != null && groups.contains(currentGroup)) {
      selectedGroup = currentGroup;
    }

    final String? newGroup = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return AlertDialog(
                  title: const Text('Schimba grupa'),
                  content: DropdownButtonFormField<String>(
                    initialValue: selectedGroup,
                    decoration: const InputDecoration(labelText: 'Grupa'),
                    items: groups
                        .map(
                          (String group) => DropdownMenuItem<String>(
                            value: group,
                            child: Text('Grupa $group'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selectedGroup = value;
                      });
                    },
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Renunta'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(selectedGroup),
                      child: const Text('Salveaza'),
                    ),
                  ],
                );
              },
        );
      },
    );

    if (!mounted || newGroup == null || newGroup == currentGroup) {
      return;
    }

    setState(() {
      _isUpdatingGroup = true;
    });

    try {
      await _repository.setCurrentGroupCode(newGroup);
      if (mounted) {
        setState(() {
          _profileFuture = _repository.fetchProfile();
          _statsFuture = _repository.fetchProfileStats();
          _semesterStatsFuture = _fetchSemesterStats();
          _isUpdatingGroup = false;
        });
        _showSnackBarAfterBuild(
          SnackBar(content: Text('Grupa $newGroup a fost salvata.')),
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnackBarAfterBuild(
          const SnackBar(content: Text('Nu am putut salva grupa.')),
        );
      }
    } finally {
      if (mounted && _isUpdatingGroup) {
        setState(() {
          _isUpdatingGroup = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    await widget.onLogout();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = false;
    });
  }

  String _weekdayLabel(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Luni',
      DateTime.tuesday => 'Marti',
      DateTime.wednesday => 'Miercuri',
      DateTime.thursday => 'Joi',
      DateTime.friday => 'Vineri',
      DateTime.saturday => 'Sambata',
      DateTime.sunday => 'Duminica',
      _ => '',
    };
  }

  String _formatDateTime(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year} $hour:$minute';
  }

  String _componentSummary(GradeComponentRecord component) {
    final List<String> parts = <String>[component.name];
    parts.add(
      component.grade == null
          ? 'fara nota'
          : component.grade!.toStringAsFixed(0),
    );
    if (component.weightPercent > 0) {
      parts.add('${component.weightPercent.toStringAsFixed(0)}%');
    }
    return parts.join(' ');
  }

  Future<void> _exportAcademicData() async {
    try {
      final List<AcademicSubjectV2> subjects = await _repository
          .fetchSubjectsV2();
      final List<ClassSession> sessions = await _repository
          .fetchClassSessionsV2();
      final List<GradeComponentRecord> components = await _repository
          .fetchGradeComponentsV2();
      final List<AcademicEvent> events = await _repository
          .fetchAcademicEventsV2(
            from: DateTime.now().subtract(const Duration(days: 365)),
            to: DateTime.utc(2030, 12, 31),
          );
      final Map<String, AcademicSubjectV2> subjectsById =
          <String, AcademicSubjectV2>{
            for (final AcademicSubjectV2 subject in subjects)
              subject.id: subject,
          };
      final List<AcademicSubjectV2> sortedSubjects =
          List<AcademicSubjectV2>.of(subjects)
            ..sort((AcademicSubjectV2 a, AcademicSubjectV2 b) {
              final int semesterOrder = a.semesterLabel.compareTo(
                b.semesterLabel,
              );
              if (semesterOrder != 0) {
                return semesterOrder;
              }
              return a.name.compareTo(b.name);
            });
      final List<ClassSession> sortedSessions = List<ClassSession>.of(sessions)
        ..sort((ClassSession a, ClassSession b) {
          final AcademicSubjectV2? subjectA = subjectsById[a.subjectId];
          final AcademicSubjectV2? subjectB = subjectsById[b.subjectId];
          final int subjectOrder = (subjectA?.name ?? '').compareTo(
            subjectB?.name ?? '',
          );
          if (subjectOrder != 0) {
            return subjectOrder;
          }
          final int weekdayOrder = a.weekday.compareTo(b.weekday);
          if (weekdayOrder != 0) {
            return weekdayOrder;
          }
          return a.startsAtMinutes.compareTo(b.startsAtMinutes);
        });
      final List<GradeComponentRecord> sortedComponents =
          List<GradeComponentRecord>.of(components)
            ..sort((GradeComponentRecord a, GradeComponentRecord b) {
              final AcademicSubjectV2? subjectA = subjectsById[a.subjectId];
              final AcademicSubjectV2? subjectB = subjectsById[b.subjectId];
              final int subjectOrder = (subjectA?.name ?? '').compareTo(
                subjectB?.name ?? '',
              );
              if (subjectOrder != 0) {
                return subjectOrder;
              }
              return a.name.compareTo(b.name);
            });
      final List<AcademicEvent> sortedEvents = List<AcademicEvent>.of(events)
        ..sort((AcademicEvent a, AcademicEvent b) {
          final DateTime aDate = a.effectiveDate ?? DateTime(9999);
          final DateTime bDate = b.effectiveDate ?? DateTime(9999);
          return aDate.compareTo(bDate);
        });
      final Map<String, List<GradeComponentRecord>> componentsBySubject =
          <String, List<GradeComponentRecord>>{};
      for (final GradeComponentRecord component in sortedComponents) {
        componentsBySubject
            .putIfAbsent(component.subjectId, () => <GradeComponentRecord>[])
            .add(component);
      }

      final List<String> lines = <String>[
        'UniHub - raport academic',
        'Generat: ${_formatDateTime(DateTime.now())}',
        '',
      ];

      for (final String semester in UniHubRepository.availableSemesters) {
        final List<AcademicSubjectV2> semesterSubjects = sortedSubjects
            .where(
              (AcademicSubjectV2 subject) => subject.semesterLabel == semester,
            )
            .toList(growable: false);
        final int semesterCredits = semesterSubjects.fold<int>(
          0,
          (int total, AcademicSubjectV2 subject) => total + subject.credits,
        );

        lines
          ..add(semester.toUpperCase())
          ..add('${semesterSubjects.length} materii | $semesterCredits credite')
          ..add('')
          ..add('Materii');
        if (semesterSubjects.isEmpty) {
          lines.add('- Nu exista materii.');
        } else {
          for (final AcademicSubjectV2 subject in semesterSubjects) {
            final String professor = subject.professor.trim().isEmpty
                ? ''
                : ' | ${subject.professor.trim()}';
            lines.add(
              '- ${subject.name} (${subject.credits} credite)$professor',
            );
          }
        }

        lines
          ..add('')
          ..add('Activitati');
        final List<ClassSession> semesterSessions = sortedSessions
            .where(
              (ClassSession session) =>
                  subjectsById[session.subjectId]?.semesterLabel == semester,
            )
            .toList(growable: false);
        if (semesterSessions.isEmpty) {
          lines.add('- Nu exista activitati.');
        } else {
          for (final ClassSession session in semesterSessions) {
            final AcademicSubjectV2? subject = subjectsById[session.subjectId];
            final String room = session.room.trim().isEmpty
                ? ''
                : ' | ${session.room.trim()}';
            final String professor = session.professor.trim().isEmpty
                ? ''
                : ' | ${session.professor.trim()}';
            lines.add(
              '- ${_weekdayLabel(session.weekday)} ${session.intervalLabel} | '
              '${subject?.name ?? 'Materie necunoscuta'} | '
              '${session.sessionType}$room$professor',
            );
          }
        }

        lines
          ..add('')
          ..add('Note si ponderi');
        bool hasGrades = false;
        for (final AcademicSubjectV2 subject in semesterSubjects) {
          final List<GradeComponentRecord> subjectComponents =
              componentsBySubject[subject.id] ?? const <GradeComponentRecord>[];
          if (subjectComponents.isEmpty) {
            continue;
          }
          hasGrades = true;
          lines.add(
            '- ${subject.name}: '
            '${subjectComponents.map(_componentSummary).join(', ')}',
          );
        }
        if (!hasGrades) {
          lines.add('- Nu exista note introduse.');
        }

        lines.add('');
      }

      lines.add('EVENIMENTE ACADEMICE');
      if (sortedEvents.isEmpty) {
        lines.add('- Nu exista evenimente academice.');
      } else {
        for (final AcademicEvent event in sortedEvents) {
          final AcademicSubjectV2? subject = event.subjectId == null
              ? null
              : subjectsById[event.subjectId];
          final DateTime? eventDate = event.effectiveDate;
          final String dateLabel = eventDate == null
              ? 'Fara data'
              : '${_weekdayLabel(eventDate.weekday)}, ${_formatDateTime(eventDate)}';
          final String room = event.room.trim().isEmpty
              ? ''
              : ' | ${event.room.trim()}';
          final String subjectName = subject == null
              ? ''
              : ' | ${subject.name}';
          final String title = event.title.trim().isEmpty
              ? ''
              : ' | ${event.title.trim()}';
          lines.add(
            '- $dateLabel | ${event.type.label}$subjectName$room$title',
          );
        }
      }

      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      if (!mounted) {
        return;
      }
      _showSnackBarAfterBuild(
        const SnackBar(content: Text('Raportul academic a fost copiat.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBarAfterBuild(
        const SnackBar(content: Text('Nu am putut exporta datele.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _profileFuture,
      builder: (BuildContext context, AsyncSnapshot<UserProfile> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return ProfileLoadError(onRetry: _reload);
        }

        return FutureBuilder<ProfileStats>(
          future: _statsFuture,
          builder: (BuildContext context, AsyncSnapshot<ProfileStats> stats) {
            return FutureBuilder<Map<String, ProfileStats>>(
              future: _semesterStatsFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<Map<String, ProfileStats>> semesterStats,
                  ) {
                    return ProfileScreenView(
                      profile: snapshot.data!,
                      stats: stats.data,
                      semesterStats: semesterStats.data ?? const {},
                      isStatsLoading:
                          stats.connectionState == ConnectionState.waiting,
                      isSemesterStatsLoading:
                          semesterStats.connectionState ==
                          ConnectionState.waiting,
                      hasStatsError: stats.hasError || semesterStats.hasError,
                      isLoggingOut: _isLoggingOut,
                      isUpdatingProfile: _isUpdatingProfile,
                      isUpdatingGroup: _isUpdatingGroup,
                      themePreference: widget.themePreference,
                      avatarColor: widget.avatarColor,
                      onRefresh: _reload,
                      onLogout: _logout,
                      onEditProfile: () =>
                          _openEditProfileDialog(snapshot.data!),
                      onChangeGroup: () =>
                          _openChangeGroupDialog(snapshot.data!.groupCode),
                      onThemePreferenceChanged: widget.onThemePreferenceChanged,
                      onAvatarColorChanged: widget.onAvatarColorChanged,
                      onExportAcademicData: _exportAcademicData,
                    );
                  },
            );
          },
        );
      },
    );
  }
}

class _ProfileEditDraft {
  const _ProfileEditDraft({
    required this.fullName,
    required this.faculty,
    required this.studyYear,
    required this.universityEmail,
  });

  final String fullName;
  final String faculty;
  final int? studyYear;
  final String universityEmail;
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _facultyController;
  late final TextEditingController _yearController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _facultyController = TextEditingController(text: widget.profile.faculty);
    _yearController = TextEditingController(
      text: widget.profile.studyYear?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.profile.universityEmail,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _facultyController.dispose();
    _yearController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  int? _parseStudyYear(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 1 || parsed > 4) {
      return null;
    }
    return parsed;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      _ProfileEditDraft(
        fullName: _nameController.text,
        faculty: _facultyController.text,
        studyYear: _parseStudyYear(_yearController.text),
        universityEmail: _emailController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editeaza profilul'),
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
                  decoration: const InputDecoration(labelText: 'Nume complet'),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Numele este obligatoriu.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _facultyController,
                  decoration: const InputDecoration(labelText: 'Facultate'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'An de studiu (1-4)',
                  ),
                  validator: (String? value) {
                    final String trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return null;
                    }
                    final int? parsed = int.tryParse(trimmed);
                    if (parsed == null || parsed < 1 || parsed > 4) {
                      return 'Introdu un an valid (1-4).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email universitar',
                  ),
                  validator: (String? value) {
                    final String email = (value ?? '').trim();
                    if (email.isEmpty || !email.contains('@')) {
                      return 'Email invalid.';
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
        FilledButton(onPressed: _save, child: const Text('Salveaza')),
      ],
    );
  }
}
