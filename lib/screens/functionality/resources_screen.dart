import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:unihub/data/schedule_visibility_store.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/course.dart';
import 'package:unihub/screens/ui/resources_screen_view.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  final ScheduleVisibilityStore _visibilityStore =
      ScheduleVisibilityStore.instance;
  static const String _notesStorageKey = 'resources_notes_by_day';
  static const String _deleteNoteAction = '@@DELETE@@';
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  Map<String, String> _notesByDay = <String, String>{};
  List<Course> _customCourses = <Course>[];
  Set<String> _hiddenScheduleSemesters = <String>{};
  bool _isLoadingCourses = false;
  bool _hasLoadError = false;
  RealtimeChannel? _coursesRealtimeChannel;
  RealtimeChannel? _notesRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _focusedDay = _normalizedDate(DateTime.now());
    _selectedDay = _normalizedDate(DateTime.now());
    unawaited(_initializeData());
    _visibilityStore.version.addListener(_handleScheduleVisibilityChanged);
    _subscribeToCoursesRealtime();
    _subscribeToNotesRealtime();
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
    _visibilityStore.version.removeListener(_handleScheduleVisibilityChanged);
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _migrateLocalNotesIfNeeded();
    await _loadScheduleVisibility();
    await _loadNotes();
    await _syncCoursesFromSupabase(showLoader: false);
  }

  void _handleScheduleVisibilityChanged() {
    unawaited(_loadScheduleVisibility());
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
    await _syncCoursesFromSupabase(showLoader: true);
    await _loadNotes();
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

  @override
  Widget build(BuildContext context) {
    final List<Course> dailyCourses = _coursesForDay(
      _customCourses,
      _selectedDay,
    );

    return ResourcesScreenView(
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      firstVisibleDay: _startOfCurrentWeek(),
      calendarFormat: _calendarFormat,
      dailyCourses: dailyCourses,
      selectedDayNote: _selectedDayNote(),
      hasNoteForDay: _hasNoteForDay,
      onOpenSelectedDayNoteEditor: _openSelectedDayNoteEditor,
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
      onRefresh: _reload,
      connectionState: _isLoadingCourses
          ? ConnectionState.waiting
          : ConnectionState.done,
      hasError: _hasLoadError,
      onRetry: _reload,
    );
  }
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
