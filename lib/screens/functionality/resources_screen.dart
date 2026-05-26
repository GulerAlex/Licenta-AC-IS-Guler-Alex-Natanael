import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:unihub/data/app_preferences_store.dart';
import 'package:unihub/data/schedule_visibility_store.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/academic_subject_v2.dart';
import 'package:unihub/models/class_session.dart';
import 'package:unihub/models/schedule_item.dart';
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
  List<AcademicSubjectV2> _subjects = <AcademicSubjectV2>[];
  List<ClassSession> _classSessions = <ClassSession>[];
  List<AcademicEvent> _academicEvents = <AcademicEvent>[];
  Set<String> _hiddenScheduleSemesters = <String>{};
  bool _isLoadingCourses = false;
  bool _hasLoadError = false;
  RealtimeChannel? _scheduleRealtimeChannel;
  RealtimeChannel? _notesRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _focusedDay = _normalizedDate(DateTime.now());
    _selectedDay = _normalizedDate(DateTime.now());
    unawaited(_initializeData());
    _visibilityStore.version.addListener(_handleScheduleVisibilityChanged);
    _preferences.addListener(_handleNotificationPreferencesChanged);
    _subscribeToScheduleRealtime();
    _subscribeToNotesRealtime();
  }

  @override
  void dispose() {
    final RealtimeChannel? channel = _scheduleRealtimeChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    final RealtimeChannel? notesChannel = _notesRealtimeChannel;
    if (notesChannel != null) {
      Supabase.instance.client.removeChannel(notesChannel);
    }
    _visibilityStore.version.removeListener(_handleScheduleVisibilityChanged);
    _preferences.removeListener(_handleNotificationPreferencesChanged);
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _migrateLocalNotesIfNeeded();
    await _loadScheduleVisibility();
    await _loadNotes();
    await _syncScheduleFromSupabase(showLoader: false);
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

  void _subscribeToScheduleRealtime() {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final RealtimeChannel channel = Supabase.instance.client
        .channel('academic-schedule-user-${user.id}')
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
            unawaited(_syncScheduleFromSupabase(showLoader: false));
          },
        )
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
            if (!mounted) {
              return;
            }
            unawaited(_syncScheduleFromSupabase(showLoader: false));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'academic_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload _) {
            if (!mounted) {
              return;
            }
            unawaited(_syncScheduleFromSupabase(showLoader: false));
          },
        )
        .subscribe();

    _scheduleRealtimeChannel = channel;
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
    await _syncScheduleFromSupabase(showLoader: true);
    await _loadNotes();
    await _rescheduleNotifications();
  }

  void _goToToday() {
    final DateTime today = _normalizedDate(DateTime.now());
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
  }

  int _sessionTypeOrder(String courseType) {
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

  Future<void> _syncScheduleFromSupabase({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoadingCourses = true;
        _hasLoadError = false;
      });
    }

    try {
      final List<AcademicSubjectV2> subjects = await _repository
          .fetchSubjectsV2();
      final List<ClassSession> sessions = await _repository
          .fetchClassSessionsV2();
      final List<AcademicEvent> events = await _repository
          .fetchAcademicEventsV2(
            from: DateTime.now().subtract(const Duration(days: 365)),
            to: DateTime.utc(2030, 12, 31),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = subjects;
        _classSessions = sessions;
        _academicEvents = events;
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

  Map<String, AcademicSubjectV2> get _subjectsById {
    return <String, AcademicSubjectV2>{
      for (final AcademicSubjectV2 subject in _subjects) subject.id: subject,
    };
  }

  List<ScheduleClassItem> _classesForDay(DateTime day) {
    final Map<String, AcademicSubjectV2> subjectsById = _subjectsById;
    final List<ScheduleClassItem> filtered = _classSessions
        .where((ClassSession session) => session.active)
        .map((ClassSession session) {
          final AcademicSubjectV2? subject = subjectsById[session.subjectId];
          if (subject == null || subject.archived) {
            return null;
          }
          return ScheduleClassItem(subject: subject, session: session);
        })
        .whereType<ScheduleClassItem>()
        .where(
          (ScheduleClassItem item) =>
              !_hiddenScheduleSemesters.contains(item.subject.semesterLabel) &&
              item.session.weekday == day.weekday,
        )
        .toList();

    filtered.sort((ScheduleClassItem a, ScheduleClassItem b) {
      if (a.session.startsAtMinutes != b.session.startsAtMinutes) {
        return a.session.startsAtMinutes.compareTo(b.session.startsAtMinutes);
      }
      return _sessionTypeOrder(
        a.session.sessionType,
      ).compareTo(_sessionTypeOrder(b.session.sessionType));
    });

    return filtered;
  }

  List<ScheduleEventItem> _eventsForDay(DateTime day) {
    final DateTime normalizedDay = _normalizedDate(day);
    final Map<String, AcademicSubjectV2> subjectsById = _subjectsById;
    final List<ScheduleEventItem> filtered = _academicEvents
        .where(
          (AcademicEvent event) =>
              event.effectiveDate != null &&
              _normalizedDate(event.effectiveDate!) == normalizedDay,
        )
        .map(
          (AcademicEvent event) => ScheduleEventItem(
            event: event,
            subject: event.subjectId == null
                ? null
                : subjectsById[event.subjectId],
          ),
        )
        .toList();
    filtered.sort((ScheduleEventItem a, ScheduleEventItem b) {
      final DateTime aDate = a.event.effectiveDate ?? DateTime(9999);
      final DateTime bDate = b.event.effectiveDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return filtered;
  }

  bool _isExamLikeEvent(ScheduleEventItem item) {
    return switch (item.event.type) {
      AcademicEventType.exam ||
      AcademicEventType.colloquium ||
      AcademicEventType.retake ||
      AcademicEventType.project => true,
      _ => false,
    };
  }

  Future<void> _rescheduleNotifications() async {
    if (!_preferences.courseNotificationsEnabled &&
        !_preferences.examNotificationsEnabled) {
      await _notificationService.cancelAcademicReminders();
      return;
    }

    await _notificationService.rescheduleAcademicRemindersV2(
      subjects: _subjects,
      classSessions: _classSessions,
      events: _academicEvents,
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
    final AcademicEvent? draft = await showDialog<AcademicEvent>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ExamEventDialog(
          selectedDay: _selectedDay,
          subjects: _subjects,
          defaultReminderMinutes: _preferences.examReminderMinutes,
        );
      },
    );

    if (!mounted || draft == null) {
      return;
    }

    try {
      await _repository.upsertAcademicEventV2(draft);
      await _syncScheduleFromSupabase(showLoader: false);
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

  Future<void> _editExamEvent(ScheduleEventItem item) async {
    final AcademicEvent event = item.event;
    final AcademicEvent? updated = await showDialog<AcademicEvent>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ExamEventDialog(
          selectedDay: _normalizedDate(event.effectiveDate ?? DateTime.now()),
          subjects: _subjects,
          defaultReminderMinutes: _preferences.examReminderMinutes,
          initialEvent: event,
        );
      },
    );

    if (!mounted || updated == null) {
      return;
    }

    try {
      await _repository.upsertAcademicEventV2(updated);
      await _syncScheduleFromSupabase(showLoader: false);
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

  Future<void> _deleteExamEvent(ScheduleEventItem item) async {
    final AcademicEvent event = item.event;
    final String label = item.subjectName.isNotEmpty
        ? item.subjectName
        : item.title;
    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Sterge eveniment'),
              content: Text('Stergi ${event.type.label} la $label?'),
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
      await _repository.deleteAcademicEventV2(event.id);
      await _syncScheduleFromSupabase(showLoader: false);
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

  @override
  Widget build(BuildContext context) {
    final List<ScheduleClassItem> dailyClasses = _classesForDay(_selectedDay);
    final List<ScheduleEventItem> dailyEvents = _eventsForDay(_selectedDay);

    return ResourcesScreenView(
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      firstVisibleDay: _startOfCurrentWeek(),
      calendarFormat: _calendarFormat,
      dailyClasses: dailyClasses,
      dailyEvents: dailyEvents,
      selectedDayNote: _selectedDayNote(),
      hasNoteForDay: _hasNoteForDay,
      hasExamForDay: (DateTime day) => _eventsForDay(day).any(_isExamLikeEvent),
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
      eventLoader: _classesForDay,
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
  final List<AcademicSubjectV2> subjects;
  final int defaultReminderMinutes;
  final AcademicEvent? initialEvent;

  @override
  State<_ExamEventDialog> createState() => _ExamEventDialogState();
}

class _ExamEventDialogState extends State<_ExamEventDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late AcademicEventType _selectedExamType;
  String? _selectedSubjectId;
  late int _selectedReminderMinutes;
  late bool _notificationsEnabled;

  static const List<AcademicEventType> _examTypes = <AcademicEventType>[
    AcademicEventType.exam,
    AcademicEventType.colloquium,
    AcademicEventType.retake,
    AcademicEventType.project,
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
    final AcademicEvent? initialEvent = widget.initialEvent;
    final DateTime initialDate =
        initialEvent?.effectiveDate ?? widget.selectedDay;
    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(
      initialEvent?.startsAt ??
          initialEvent?.dueAt ??
          DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            9,
          ),
    );
    _selectedExamType = initialEvent?.type ?? _examTypes.first;
    final String? initialSubjectId = initialEvent?.subjectId;
    final bool hasInitialSubject =
        initialSubjectId != null &&
        widget.subjects.any(
          (AcademicSubjectV2 subject) => subject.id == initialSubjectId,
        );
    _selectedSubjectId = hasInitialSubject
        ? initialSubjectId
        : (widget.subjects.isNotEmpty ? widget.subjects.first.id : null);
    _selectedReminderMinutes =
        initialEvent?.reminderMinutesBefore ?? widget.defaultReminderMinutes;
    _notificationsEnabled = initialEvent?.notificationsEnabled ?? true;
    _roomController.text = initialEvent?.room ?? '';
    _notesController.text = initialEvent?.notes ?? '';
  }

  @override
  void dispose() {
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

    Navigator.of(context).pop<AcademicEvent>(
      AcademicEvent(
        id: widget.initialEvent?.id ?? '',
        subjectId: _selectedSubjectId,
        type: _selectedExamType,
        title: _selectedExamType.label,
        startsAt: startsAt,
        dueAt: null,
        room: _roomController.text.trim(),
        notes: _notesController.text.trim(),
        priority: widget.initialEvent?.priority ?? AcademicPriority.high,
        status: widget.initialEvent?.status ?? AcademicEventStatus.planned,
        reminderMinutesBefore: _selectedReminderMinutes,
        notificationsEnabled: _notificationsEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<AcademicSubjectV2> subjectOptions =
        List<AcademicSubjectV2>.of(widget.subjects)..sort(
          (AcademicSubjectV2 a, AcademicSubjectV2 b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
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
                if (subjectOptions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubjectId,
                    decoration: const InputDecoration(labelText: 'Materie'),
                    items: subjectOptions
                        .map(
                          (AcademicSubjectV2 subject) =>
                              DropdownMenuItem<String>(
                                value: subject.id,
                                child: Text(subject.name),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedSubjectId = value;
                      });
                    },
                  )
                else
                  const Text(
                    'Nu ai materii in schema noua. Poti salva evenimentul fara materie.',
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AcademicEventType>(
                  initialValue: _selectedExamType,
                  decoration: const InputDecoration(labelText: 'Tip'),
                  items: _examTypes
                      .map(
                        (AcademicEventType type) =>
                            DropdownMenuItem<AcademicEventType>(
                              value: type,
                              child: Text(type.label),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (AcademicEventType? value) {
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
