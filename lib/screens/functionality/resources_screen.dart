import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:unihub/data/app_preferences_store.dart';
import 'package:unihub/data/schedule_visibility_store.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/models/exam_event.dart';
import 'package:unihub/screens/ui/resources_screen_view.dart';
import 'package:unihub/services/notification_service.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  final AppPreferencesStore _preferences = AppPreferencesStore.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final ScheduleVisibilityStore _visibilityStore =
      ScheduleVisibilityStore.instance;
  static const String _notesStorageKey = 'resources_notes_by_day';
  static const String _deleteNoteAction = '@@DELETE@@';
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  Map<String, String> _notesByDay = <String, String>{};
  List<Course> _customCourses = <Course>[];
  List<ExamEvent> _examEvents = <ExamEvent>[];
  Set<String> _hiddenScheduleSemesters = <String>{};
  bool _isLoadingCourses = false;
  bool _hasLoadError = false;
  RealtimeChannel? _coursesRealtimeChannel;
  RealtimeChannel? _notesRealtimeChannel;
  RealtimeChannel? _examEventsRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _focusedDay = _normalizedDate(DateTime.now());
    _selectedDay = _normalizedDate(DateTime.now());
    unawaited(_initializeData());
    _visibilityStore.version.addListener(_handleScheduleVisibilityChanged);
    _preferences.addListener(_handleNotificationPreferencesChanged);
    _subscribeToCoursesRealtime();
    _subscribeToNotesRealtime();
    _subscribeToExamEventsRealtime();
  }

  @override
  void dispose() {
    final RealtimeChannel? channel = _coursesRealtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    final RealtimeChannel? notesChannel = _notesRealtimeChannel;
    if (notesChannel != null) {
      Supabase.instance.client.removeChannel(notesChannel);
    }
    final RealtimeChannel? examEventsChannel = _examEventsRealtimeChannel;
    if (examEventsChannel != null) {
      Supabase.instance.client.removeChannel(examEventsChannel);
    }
    _visibilityStore.version.removeListener(_handleScheduleVisibilityChanged);
    _preferences.removeListener(_handleNotificationPreferencesChanged);
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _migrateLocalNotesIfNeeded();
    await _loadScheduleVisibility();
    await _loadNotes();
    await _loadExamEvents();
    await _syncCoursesFromSupabase(showLoader: false);
    await _rescheduleNotifications();
  }

  void _handleScheduleVisibilityChanged() {
    unawaited(_loadScheduleVisibility());
  }

  void _handleNotificationPreferencesChanged() {
    unawaited(_rescheduleNotifications());
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
    unawaited(_rescheduleNotifications());
  }

  void _subscribeToCoursesRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('courses-user-${user.id}')
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
            unawaited(_syncCoursesFromSupabase(showLoader: false));
          },
        )
        .subscribe();

    _coursesRealtimeChannel = channel;
  }

  void _subscribeToNotesRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('resource-notes-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'resource_notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            unawaited(_loadNotes());
          },
        )
        .subscribe();

    _notesRealtimeChannel = channel;
  }

  void _subscribeToExamEventsRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('exam-events-user-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'exam_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            unawaited(_loadExamEvents());
          },
        )
        .subscribe();

    _examEventsRealtimeChannel = channel;
  }

  Future<void> _loadNotes() async {
    try {
      final Map<String, String> notes = await _repository.fetchResourceNotes();
      if (!mounted) {
        return;
      }
      setState(() {
        _notesByDay = notes;
      });
    } catch (e) {
      debugPrint('Failed to load resource notes: $e');
    }
  }

  Future<void> _loadExamEvents() async {
    try {
      final List<ExamEvent> exams = await _repository.fetchExamEvents();
      if (!mounted) {
        return;
      }
      setState(() {
        _examEvents = exams;
      });
      unawaited(_rescheduleNotifications());
    } catch (e) {
      debugPrint('Failed to load exam events: $e');
    }
  }

  Future<void> _migrateLocalNotesIfNeeded() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_notesStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final Map<String, String> parsed = <String, String>{};
    decoded.forEach((dynamic key, dynamic value) {
      final String keyText = key.toString().trim();
      final String valueText = value.toString().trim();
      if (keyText.isNotEmpty && valueText.isNotEmpty) {
        parsed[keyText] = valueText;
      }
    });

    if (parsed.isEmpty) {
      return;
    }

    try {
      await _repository.upsertResourceNotes(parsed);
      await prefs.remove(_notesStorageKey);
    } catch (e) {
      debugPrint('Failed to migrate resource notes: $e');
    }
  }

  Future<void> _reload() async {
    await _syncCoursesFromSupabase(showLoader: true);
    await _loadNotes();
    await _loadExamEvents();
    await _rescheduleNotifications();
  }

  void _goToToday() {
    final DateTime today = _normalizedDate(DateTime.now());
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
  }

  int _courseTypeOrder(String courseType) {
    return switch (courseType) {
      'Curs' => 0,
      'Seminar' => 1,
      'Laborator' => 2,
      _ => 99,
    };
  }

  DateTime _normalizedDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _startOfCurrentWeek() {
    final DateTime now = _normalizedDate(DateTime.now());
    return now.subtract(Duration(days: now.weekday - DateTime.monday));
  }

  String _dayKey(DateTime day) {
    final String year = day.year.toString().padLeft(4, '0');
    final String month = day.month.toString().padLeft(2, '0');
    final String date = day.day.toString().padLeft(2, '0');
    return '$year-$month-$date';
  }

  String? _selectedDayNote() {
    return _notesByDay[_dayKey(_selectedDay)];
  }

  bool _hasNoteForDay(DateTime day) {
    final String? note = _notesByDay[_dayKey(_normalizedDate(day))];
    return (note ?? '').trim().isNotEmpty;
  }

  Future<void> _saveNoteForSelectedDay(String noteText) async {
    final String normalized = noteText.trim();
    final String key = _dayKey(_selectedDay);

    setState(() {
      if (normalized.isEmpty) {
        _notesByDay.remove(key);
      } else {
        _notesByDay[key] = normalized;
      }
    });

    try {
      await _repository.setResourceNote(dateKey: key, noteText: normalized);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-a putut salva notita.')),
        );
      }
      await _loadNotes();
    }
  }

  Future<void> _deleteNoteForSelectedDay() async {
    final String key = _dayKey(_selectedDay);
    if (!_notesByDay.containsKey(key)) {
      return;
    }

    setState(() {
      _notesByDay.remove(key);
    });

    try {
      await _repository.deleteResourceNote(dateKey: key);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu s-a putut sterge notita.')),
        );
      }
      await _loadNotes();
    }
  }

  Future<void> _openSelectedDayNoteEditor() async {
    final String initialText = _selectedDayNote() ?? '';
    String draft = initialText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Notita pentru ${_formatSelectedDate(_selectedDay)}'),
          content: TextFormField(
            initialValue: initialText,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            onChanged: (String value) {
              draft = value;
            },
            decoration: const InputDecoration(
              hintText: 'Scrie notita ta aici...',
            ),
          ),
          actions: <Widget>[
            if (initialText.trim().isNotEmpty)
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_deleteNoteAction),
                child: const Text('Sterge'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Renunta'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draft),
              child: const Text('Salveaza'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (result == _deleteNoteAction) {
      await _deleteNoteForSelectedDay();
      return;
    }

    await _saveNoteForSelectedDay(result);
  }

  Future<void> _syncCoursesFromSupabase({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoadingCourses = true;
        _hasLoadError = false;
      });
    }

    try {
      final List<Course> remoteCourses = await _repository.fetchUserCourses();

      if (!mounted) {
        return;
      }

      setState(() {
        _customCourses = remoteCourses;
        _isLoadingCourses = false;
        _hasLoadError = false;
      });
      unawaited(_rescheduleNotifications());
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingCourses = false;
        _hasLoadError = true;
      });
    }
  }

  List<Course> _coursesForDay(List<Course> courses, DateTime day) {
    final String dayLabel = _weekdayLabel(day.weekday);
    final List<Course> filtered = courses
        .where(
          (Course course) =>
              !_hiddenScheduleSemesters.contains(course.semesterLabel) &&
              course.weekdayLabel == dayLabel &&
              course.time != UniHubRepository.pendingCourseTimeLabel,
        )
        .toList();

    filtered.sort((Course a, Course b) {
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      return _courseTypeOrder(
        a.courseType,
      ).compareTo(_courseTypeOrder(b.courseType));
    });

    return filtered;
  }

  List<ExamEvent> _examsForDay(List<ExamEvent> exams, DateTime day) {
    final DateTime normalizedDay = _normalizedDate(day);
    final List<ExamEvent> filtered = exams
        .where(
          (ExamEvent exam) => _normalizedDate(exam.startsAt) == normalizedDay,
        )
        .toList();
    filtered.sort(
      (ExamEvent a, ExamEvent b) => a.startsAt.compareTo(b.startsAt),
    );
    return filtered;
  }

  Future<void> _rescheduleNotifications() async {
    if (!_preferences.courseNotificationsEnabled &&
        !_preferences.examNotificationsEnabled) {
      await _notificationService.cancelAcademicReminders();
      return;
    }

    await _notificationService.rescheduleAcademicReminders(
      courses: _customCourses,
      exams: _examEvents,
      hiddenScheduleSemesters: _hiddenScheduleSemesters,
      courseNotificationsEnabled: _preferences.courseNotificationsEnabled,
      examNotificationsEnabled: _preferences.examNotificationsEnabled,
      courseReminderMinutes: _preferences.courseReminderMinutes,
    );
  }

  Future<void> _openNotificationSettings() async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _NotificationSettingsDialog(
          courseNotificationsEnabled: _preferences.courseNotificationsEnabled,
          examNotificationsEnabled: _preferences.examNotificationsEnabled,
          courseReminderMinutes: _preferences.courseReminderMinutes,
          examReminderMinutes: _preferences.examReminderMinutes,
        );
      },
    );

    if (!mounted || changed != true) {
      return;
    }

    if (_preferences.courseNotificationsEnabled ||
        _preferences.examNotificationsEnabled) {
      final bool granted = await _notificationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisiunea pentru notificari nu a fost acordata.'),
          ),
        );
      }
    }
    await _rescheduleNotifications();
  }

  Future<void> _openAddExamDialog() async {
    final List<String> subjects = _subjectOptions();
    final ExamEvent? draft = await showDialog<ExamEvent>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ExamEventDialog(
          selectedDay: _selectedDay,
          subjects: subjects,
          defaultReminderMinutes: _preferences.examReminderMinutes,
        );
      },
    );

    if (!mounted || draft == null) {
      return;
    }

    try {
      await _repository.addExamEvent(draft);
      await _loadExamEvents();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Examenul a fost adaugat.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut salva examenul.')),
      );
    }
  }

  Future<void> _editExamEvent(ExamEvent exam) async {
    final ExamEvent? updated = await showDialog<ExamEvent>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ExamEventDialog(
          selectedDay: _normalizedDate(exam.startsAt),
          subjects: _subjectOptions(),
          defaultReminderMinutes: _preferences.examReminderMinutes,
          initialEvent: exam,
        );
      },
    );

    if (!mounted || updated == null) {
      return;
    }

    try {
      await _repository.updateExamEvent(updated);
      await _loadExamEvents();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Examenul a fost actualizat.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut actualiza examenul.')),
      );
    }
  }

  Future<void> _deleteExamEvent(ExamEvent exam) async {
    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Sterge examen'),
              content: Text('Stergi ${exam.examType} la ${exam.subjectName}?'),
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

    try {
      await _repository.deleteExamEvent(exam.id);
      await _loadExamEvents();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Examenul a fost sters.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut sterge examenul.')),
      );
    }
  }

  List<String> _subjectOptions() {
    final Set<String> subjects = _customCourses
        .map((Course course) => course.name.trim())
        .where((String subject) => subject.isNotEmpty)
        .toSet();
    return subjects.toList(
      growable: false,
    )..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final List<Course> dailyCourses = _coursesForDay(
      _customCourses,
      _selectedDay,
    );
    final List<ExamEvent> dailyExams = _examsForDay(_examEvents, _selectedDay);

    return ResourcesScreenView(
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      firstVisibleDay: _startOfCurrentWeek(),
      calendarFormat: _calendarFormat,
      dailyCourses: dailyCourses,
      dailyExams: dailyExams,
      selectedDayNote: _selectedDayNote(),
      hasNoteForDay: _hasNoteForDay,
      hasExamForDay: (DateTime day) =>
          _examsForDay(_examEvents, day).isNotEmpty,
      onOpenSelectedDayNoteEditor: _openSelectedDayNoteEditor,
      onOpenAddExam: _openAddExamDialog,
      onEditExam: _editExamEvent,
      onDeleteExam: _deleteExamEvent,
      onOpenNotificationSettings: _openNotificationSettings,
      onGoToToday: _goToToday,
      onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
        setState(() {
          _selectedDay = _normalizedDate(selectedDay);
          _focusedDay = _normalizedDate(focusedDay);
        });
      },
      onFormatChanged: (CalendarFormat format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (DateTime focusedDay) {
        setState(() {
          _focusedDay = _normalizedDate(focusedDay);
        });
      },
      eventLoader: (DateTime day) => _coursesForDay(_customCourses, day),
      courseNotificationsEnabled: _preferences.courseNotificationsEnabled,
      examNotificationsEnabled: _preferences.examNotificationsEnabled,
      onRefresh: _reload,
      connectionState: _isLoadingCourses
          ? ConnectionState.waiting
          : ConnectionState.done,
      hasError: _hasLoadError,
      onRetry: _reload,
    );
  }
}

class _NotificationSettingsDialog extends StatefulWidget {
  const _NotificationSettingsDialog({
    required this.courseNotificationsEnabled,
    required this.examNotificationsEnabled,
    required this.courseReminderMinutes,
    required this.examReminderMinutes,
  });

  final bool courseNotificationsEnabled;
  final bool examNotificationsEnabled;
  final int courseReminderMinutes;
  final int examReminderMinutes;

  @override
  State<_NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<_NotificationSettingsDialog> {
  final AppPreferencesStore _preferences = AppPreferencesStore.instance;
  late bool _courseNotificationsEnabled;
  late bool _examNotificationsEnabled;
  late int _courseReminderMinutes;
  late int _examReminderMinutes;

  static const Map<int, String> _courseReminderOptions = <int, String>{
    15: '15 minute',
    30: '30 minute',
    60: '1 ora',
    120: '2 ore',
  };

  static const Map<int, String> _examReminderOptions = <int, String>{
    60: '1 ora',
    180: '3 ore',
    1440: '1 zi',
    4320: '3 zile',
  };

  @override
  void initState() {
    super.initState();
    _courseNotificationsEnabled = widget.courseNotificationsEnabled;
    _examNotificationsEnabled = widget.examNotificationsEnabled;
    _courseReminderMinutes = widget.courseReminderMinutes;
    _examReminderMinutes = widget.examReminderMinutes;
  }

  Future<void> _save() async {
    await _preferences.setCourseNotificationsEnabled(
      _courseNotificationsEnabled,
    );
    await _preferences.setExamNotificationsEnabled(_examNotificationsEnabled);
    await _preferences.setCourseReminderMinutes(_courseReminderMinutes);
    await _preferences.setExamReminderMinutes(_examReminderMinutes);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reminder-e'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SwitchListTile(
                value: _courseNotificationsEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _courseNotificationsEnabled = value;
                  });
                },
                title: const Text('Cursuri, seminare, laboratoare'),
                subtitle: const Text(
                  'Programate pentru urmatoarele 4 saptamani',
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: _courseReminderMinutes,
                decoration: const InputDecoration(labelText: 'Inainte de curs'),
                items: _courseReminderOptions.entries
                    .map(
                      (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _courseNotificationsEnabled
                    ? (int? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _courseReminderMinutes = value;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _examNotificationsEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _examNotificationsEnabled = value;
                  });
                },
                title: const Text('Examene'),
                subtitle: const Text(
                  'Fiecare examen poate avea reminder propriu',
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: _examReminderMinutes,
                decoration: const InputDecoration(
                  labelText: 'Default inainte de examen',
                ),
                items: _examReminderOptions.entries
                    .map(
                      (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _examNotificationsEnabled
                    ? (int? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _examReminderMinutes = value;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Renunta'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salveaza')),
      ],
    );
  }
}

class _ExamEventDialog extends StatefulWidget {
  const _ExamEventDialog({
    required this.selectedDay,
    required this.subjects,
    required this.defaultReminderMinutes,
    this.initialEvent,
  });

  final DateTime selectedDay;
  final List<String> subjects;
  final int defaultReminderMinutes;
  final ExamEvent? initialEvent;

  @override
  State<_ExamEventDialog> createState() => _ExamEventDialogState();
}

class _ExamEventDialogState extends State<_ExamEventDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedExamType;
  late int _selectedReminderMinutes;
  late bool _notificationsEnabled;

  static const List<String> _examTypes = <String>[
    'Examen',
    'Colocviu',
    'Restanta',
    'Proiect',
  ];

  static const Map<int, String> _reminderOptions = <int, String>{
    60: '1 ora',
    180: '3 ore',
    1440: '1 zi',
    4320: '3 zile',
  };

  @override
  void initState() {
    super.initState();
    final ExamEvent? initialEvent = widget.initialEvent;
    _selectedDate = initialEvent != null
        ? DateTime(
            initialEvent.startsAt.year,
            initialEvent.startsAt.month,
            initialEvent.startsAt.day,
          )
        : widget.selectedDay;
    _selectedTime = TimeOfDay.fromDateTime(
      initialEvent?.startsAt ??
          DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            9,
          ),
    );
    _selectedExamType = initialEvent?.examType ?? _examTypes.first;
    _selectedReminderMinutes =
        initialEvent?.reminderMinutesBefore ?? widget.defaultReminderMinutes;
    _notificationsEnabled = initialEvent?.notificationsEnabled ?? true;
    _subjectController.text =
        initialEvent?.subjectName ??
        (widget.subjects.isNotEmpty ? widget.subjects.first : '');
    _roomController.text = initialEvent?.room ?? '';
    _notesController.text = initialEvent?.notes ?? '';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _roomController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.utc(2030, 12, 31),
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _selectedTime = time;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final DateTime startsAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (startsAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alege o data viitoare pentru examen.')),
      );
      return;
    }

    Navigator.of(context).pop<ExamEvent>(
      ExamEvent(
        id: widget.initialEvent?.id ?? '',
        subjectName: _subjectController.text.trim(),
        examType: _selectedExamType,
        startsAt: startsAt,
        room: _roomController.text.trim(),
        notes: _notesController.text.trim(),
        reminderMinutesBefore: _selectedReminderMinutes,
        notificationsEnabled: _notificationsEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> subjectOptions =
        <String>{
          ...widget.subjects,
          if (_subjectController.text.trim().isNotEmpty)
            _subjectController.text.trim(),
        }.toList(growable: false)..sort(
          (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
        );
    final Map<int, String> reminderOptions = <int, String>{
      ..._reminderOptions,
      if (!_reminderOptions.containsKey(_selectedReminderMinutes))
        _selectedReminderMinutes: _formatReminderLabel(
          _selectedReminderMinutes,
        ),
    };

    return AlertDialog(
      title: Text(
        widget.initialEvent == null ? 'Adauga examen' : 'Editeaza examen',
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (subjectOptions.isEmpty)
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: 'Materie'),
                    validator: _requiredValidator,
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _subjectController.text,
                    decoration: const InputDecoration(labelText: 'Materie'),
                    items: subjectOptions
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
                      _subjectController.text = value;
                    },
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedExamType,
                  decoration: const InputDecoration(labelText: 'Tip'),
                  items: _examTypes
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
                      _selectedExamType = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event_rounded),
                        label: Text(_formatDateKey(_selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _roomController,
                  decoration: const InputDecoration(labelText: 'Sala'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _notificationsEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                  title: const Text('Reminder pentru examen'),
                  contentPadding: EdgeInsets.zero,
                ),
                DropdownButtonFormField<int>(
                  initialValue: _selectedReminderMinutes,
                  decoration: const InputDecoration(labelText: 'Reminder'),
                  items: reminderOptions.entries
                      .map(
                        (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _notificationsEnabled
                      ? (int? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedReminderMinutes = value;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notite'),
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
        FilledButton(onPressed: _submit, child: const Text('Salveaza')),
      ],
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Camp obligatoriu';
    }
    return null;
  }

  String _formatReminderLabel(int minutes) {
    if (minutes >= 1440 && minutes % 1440 == 0) {
      final int days = minutes ~/ 1440;
      return days == 1 ? '1 zi' : '$days zile';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      final int hours = minutes ~/ 60;
      return hours == 1 ? '1 ora' : '$hours ore';
    }
    return '$minutes minute';
  }
}

String _formatDateKey(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year.toString().padLeft(4, '0')}';
}

String _formatSelectedDate(DateTime date) {
  const List<String> months = <String>[
    'Ianuarie',
    'Februarie',
    'Martie',
    'Aprilie',
    'Mai',
    'Iunie',
    'Iulie',
    'August',
    'Septembrie',
    'Octombrie',
    'Noiembrie',
    'Decembrie',
  ];

  return '${_weekdayLabel(date.weekday)}, ${date.day} ${months[date.month - 1]}';
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
    _ => 'Luni',
  };
}
