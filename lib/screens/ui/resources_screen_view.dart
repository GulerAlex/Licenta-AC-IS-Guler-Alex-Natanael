import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:unihub/models/course.dart';

class ResourcesScreenView extends StatelessWidget {
  const ResourcesScreenView({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.firstVisibleDay,
    required this.calendarFormat,
    required this.dailyCourses,
    required this.selectedDayNote,
    required this.hasNoteForDay,
    required this.onOpenSelectedDayNoteEditor,
    required this.onGoToToday,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
    required this.eventLoader,
    required this.onRefresh,
    required this.connectionState,
    required this.hasError,
    required this.onRetry,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final DateTime firstVisibleDay;
  final CalendarFormat calendarFormat;
  final List<Course> dailyCourses;
  final String? selectedDayNote;
  final bool Function(DateTime day) hasNoteForDay;
  final Future<void> Function() onOpenSelectedDayNoteEditor;
  final VoidCallback onGoToToday;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;
  final List<Course> Function(DateTime day) eventLoader;
  final Future<void> Function() onRefresh;
  final ConnectionState connectionState;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isLoading = connectionState == ConnectionState.waiting;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
            children: <Widget>[
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (hasError)
                ResourcesLoadError(onRetry: onRetry)
              else ...<Widget>[
                _GlassCard(
                  colors: colors,
                  radius: 18,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Orar din saptamana curenta',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: onGoToToday,
                            icon: const Icon(Icons.today, size: 18),
                            label: const Text('Astazi'),
                          ),
                        ],
                      ),
                      TableCalendar<Course>(
                        firstDay: firstVisibleDay,
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: focusedDay,
                        selectedDayPredicate: (DateTime day) {
                          return isSameDay(day, selectedDay);
                        },
                        calendarFormat: calendarFormat,
                        eventLoader: eventLoader,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        availableCalendarFormats:
                            const <CalendarFormat, String>{
                              CalendarFormat.week: 'Saptamana',
                              CalendarFormat.twoWeeks: '2 saptamani',
                              CalendarFormat.month: 'Luna',
                            },
                        onDaySelected: onDaySelected,
                        onFormatChanged: onFormatChanged,
                        onPageChanged: onPageChanged,
                        calendarBuilders: CalendarBuilders<Course>(
                          markerBuilder:
                              (
                                BuildContext context,
                                DateTime day,
                                List<Course> events,
                              ) {
                                final bool hasNote = hasNoteForDay(day);
                                final int eventCount = events.length;
                                if (!hasNote && eventCount == 0) {
                                  return null;
                                }

                                final List<Color> markerColors = <Color>[];
                                if (hasNote) {
                                  markerColors.add(colors.tertiary);
                                }

                                final int maxCourseDots = hasNote ? 2 : 3;
                                for (
                                  int i = 0;
                                  i < eventCount && i < maxCourseDots;
                                  i++
                                ) {
                                  markerColors.add(colors.primary);
                                }

                                return Positioned(
                                  bottom: 4,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: markerColors
                                        .map(
                                          (Color color) => Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 1,
                                            ),
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                );
                              },
                        ),
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonDecoration: BoxDecoration(
                            border: Border.all(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          formatButtonTextStyle: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          markersMaxCount: 3,
                          markerSize: 5,
                          markerDecoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          todayTextStyle: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  colors: colors,
                  radius: 14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        _formatSelectedDate(selectedDay),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onOpenSelectedDayNoteEditor,
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: Text(
                          (selectedDayNote ?? '').trim().isEmpty
                              ? 'Adauga notita'
                              : 'Editeaza notita',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${dailyCourses.length} ${dailyCourses.length == 1 ? 'curs' : 'cursuri'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if ((selectedDayNote ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _GlassCard(
                    colors: colors,
                    radius: 14,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notita zilei',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(selectedDayNote!.trim()),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (dailyCourses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 28),
                    child: Center(
                      child: Text('Nu exista cursuri disponibile.'),
                    ),
                  )
                else
                  ...dailyCourses.map(
                    (Course course) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CourseCard(course: course),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.colors,
    this.radius = 16,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final ColorScheme colors;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withOpacity(0.12),
                colors.secondary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: colors.primary.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withOpacity(0.12),
                colors.secondary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        course.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(course.courseType),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Interval',
                  value: course.time,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.room_outlined,
                  label: 'Sala',
                  value: course.room,
                ),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Profesor',
                  value: course.professor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResourcesLoadError extends StatelessWidget {
  const ResourcesLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Nu s-a putut incarca orarul.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reincearca')),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

String _formatSelectedDate(DateTime date) {
  const List<String> weekdays = <String>[
    'Luni',
    'Marti',
    'Miercuri',
    'Joi',
    'Vineri',
    'Sambata',
    'Duminica',
  ];

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

  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}
