import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleVisibilityStore {
  ScheduleVisibilityStore._();

  static final ScheduleVisibilityStore instance = ScheduleVisibilityStore._();

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  String _storageKey() {
    final String userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return 'hidden_schedule_semesters_$userId';
  }

  Future<Set<String>> fetchHiddenSemesters() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey()) ?? <String>[]).toSet();
  }

  Future<bool> isSemesterVisible(String semesterLabel) async {
    final Set<String> hiddenSemesters = await fetchHiddenSemesters();
    return !hiddenSemesters.contains(semesterLabel);
  }

  Future<void> setSemesterVisible({
    required String semesterLabel,
    required bool isVisible,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> hiddenSemesters =
        (prefs.getStringList(_storageKey()) ?? <String>[]).toSet();

    if (isVisible) {
      hiddenSemesters.remove(semesterLabel);
    } else {
      hiddenSemesters.add(semesterLabel);
    }

    await prefs.setStringList(
      _storageKey(),
      hiddenSemesters.toList(growable: false)..sort(),
    );
    version.value += 1;
  }
}
