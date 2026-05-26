import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:unihub/models/course.dart';
import 'package:unihub/screens/ui/noise_overlay.dart';

class CalendarScreenView extends StatefulWidget {
  const CalendarScreenView({
    super.key,
    required this.selectedSemester,
    required this.onSemesterChanged,
    required this.onAddCourse,
    required this.onDeleteCourse,
    required this.onSubjectTap,
    required this.onEditCourseType,
    required this.onDeleteCourseType,
    required this.isAddingCourse,
    required this.isDeletingCourse,
    required this.isEditingCourseType,
    required this.isDeletingCourseType,
    required this.pendingTimeLabel,
    required this.onRefresh,
    required this.connectionState,
    required this.hasError,
    required this.subjectEntries,
    required this.onRetry,
  });

  final String selectedSemester;
  final ValueChanged<String> onSemesterChanged;
  final Future<void> Function() onAddCourse;
  final Future<void> Function() onDeleteCourse;
  final ValueChanged<String> onSubjectTap;
  final Future<void> Function(String subjectName, Course course)
  onEditCourseType;
  final Future<void> Function(String subjectName, Course course)
  onDeleteCourseType;
  final bool isAddingCourse;
  final bool isDeletingCourse;
  final bool isEditingCourseType;
  final bool isDeletingCourseType;
  final String pendingTimeLabel;
  final Future<void> Function() onRefresh;
  final ConnectionState connectionState;
  final bool hasError;
  final List<MapEntry<String, List<Course>>> subjectEntries;
  final VoidCallback onRetry;

  @override
  State<CalendarScreenView> createState() => _CalendarScreenViewState();
}

class _CalendarScreenViewState extends State<CalendarScreenView> {
  bool _addButtonHovered = false;
  bool _deleteButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Enhanced vibrant gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.grey.shade900,
                      Colors.black,
                      Colors.black,
                      Colors.grey.shade900,
                    ]
                  : [
                      Colors.grey.shade100,
                      Colors.white,
                      Colors.white,
                      Colors.grey.shade100,
                    ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        // Noise Texture
        const NoiseOverlay(),
        // Main content
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              // Modern semester selector
              _buildModernSemesterSelector(colors),
              const SizedBox(height: 20),
              // Modern action buttons
              _buildActionButtons(colors),
              const SizedBox(height: 20),
              // Content area
              if (widget.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.hasError)
                CalendarLoadError(onRetry: widget.onRetry)
              else if (widget.subjectEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      'Nu exista cursuri pentru acest semestru.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                ...widget.subjectEntries.map(
                  (MapEntry<String, List<Course>> entry) => _SubjectCard(
                    subjectName: entry.key,
                    courses: entry.value,
                    pendingTimeLabel: widget.pendingTimeLabel,
                    onTap: () => widget.onSubjectTap(entry.key),
                    onEditCourseType: widget.onEditCourseType,
                    onDeleteCourseType: widget.onDeleteCourseType,
                    isEditingCourseType: widget.isEditingCourseType,
                    isDeletingCourseType: widget.isDeletingCourseType,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernSemesterSelector(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.15), width: 1.5),
      ),
      child: SegmentedButton<String>(
        segments: const <ButtonSegment<String>>[
          ButtonSegment<String>(
            value: 'Semestrul 1',
            label: Text('Semestrul 1'),
          ),
          ButtonSegment<String>(
            value: 'Semestrul 2',
            label: Text('Semestrul 2'),
          ),
        ],
        selected: <String>{widget.selectedSemester},
        onSelectionChanged: (Set<String> selection) {
          widget.onSemesterChanged(selection.first);
        },
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colors) {
    return Row(
      children: <Widget>[
        // Add button
        Expanded(
          child: MouseRegion(
            onEnter: (_) => setState(() => _addButtonHovered = true),
            onExit: (_) => setState(() => _addButtonHovered = false),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primary, colors.secondary.withOpacity(0.9)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(
                      _addButtonHovered ? 0.4 : 0.2,
                    ),
                    blurRadius: _addButtonHovered ? 20 : 12,
                    offset: const Offset(0, 8),
                    spreadRadius: _addButtonHovered ? 2 : 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isAddingCourse ? null : widget.onAddCourse,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.isAddingCourse
                              ? 'Se adauga...'
                              : 'Adauga materie',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Delete button
        Expanded(
          child: MouseRegion(
            onEnter: (_) => setState(() => _deleteButtonHovered = true),
            onExit: (_) => setState(() => _deleteButtonHovered = false),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.error.withOpacity(0.9),
                    colors.error.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.error.withOpacity(
                      _deleteButtonHovered ? 0.3 : 0.15,
                    ),
                    blurRadius: _deleteButtonHovered ? 18 : 10,
                    offset: const Offset(0, 8),
                    spreadRadius: _deleteButtonHovered ? 1 : 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isDeletingCourse ? null : widget.onDeleteCourse,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isDeletingCourse
                              ? 'Se sterge...'
                              : 'Sterge materie',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CalendarLoadError extends StatelessWidget {
  const CalendarLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Nu s-au putut incarca cursurile.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reincearca')),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    required this.subjectName,
    required this.courses,
    required this.pendingTimeLabel,
    required this.onTap,
    required this.onEditCourseType,
    required this.onDeleteCourseType,
    required this.isEditingCourseType,
    required this.isDeletingCourseType,
  });

  final String subjectName;
  final List<Course> courses;
  final String pendingTimeLabel;
  final VoidCallback onTap;
  final Future<void> Function(String subjectName, Course course)
  onEditCourseType;
  final Future<void> Function(String subjectName, Course course)
  onDeleteCourseType;
  final bool isEditingCourseType;
  final bool isDeletingCourseType;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<Course> detailedCourses = widget.courses
        .where((Course course) => course.time != widget.pendingTimeLabel)
        .toList(growable: false);
    final int subjectCredits = widget.courses.isNotEmpty
        ? widget.courses.first.credits
        : 5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
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
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(_isHovered ? 0.25 : 0.12),
                    blurRadius: _isHovered ? 20 : 10,
                    offset: Offset(0, _isHovered ? 12 : 6),
                    spreadRadius: _isHovered ? 2 : 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.subjectName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary.withOpacity(0.3),
                                    colors.secondary.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$subjectCredits credite',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.add_circle_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (detailedCourses.isEmpty)
                          Text(
                            'Apasa pentru a adauga tipul, ziua, ora, sala si profesorul.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                          )
                        else
                          ...detailedCourses.map(
                            (Course course) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colors.secondary.withOpacity(0.4),
                                          colors.tertiary.withOpacity(0.3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      course.courseType,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          '${course.weekdayLabel} • ${course.time} • ${course.room}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          course.professor,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: widget.isEditingCourseType
                                        ? null
                                        : () => widget.onEditCourseType(
                                            widget.subjectName,
                                            course,
                                          ),
                                    icon: Icon(
                                      Icons.edit_rounded,
                                      color: colors.primary,
                                      size: 20,
                                    ),
                                    tooltip: 'Editeaza',
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: widget.isDeletingCourseType
                                        ? null
                                        : () => widget.onDeleteCourseType(
                                            widget.subjectName,
                                            course,
                                          ),
                                    icon: Icon(
                                      Icons.delete_rounded,
                                      color: colors.error,
                                      size: 20,
                                    ),
                                    tooltip: 'Sterge',
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
