import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:unihub/models/subject_schedule_entry.dart';

class SubjectsScreenView extends StatefulWidget {
  const SubjectsScreenView({
    super.key,
    required this.selectedSemester,
    required this.isSelectedSemesterVisibleInSchedule,
    required this.isUpdatingSemesterVisibility,
    required this.onSemesterChanged,
    required this.onScheduleVisibilityChanged,
    required this.onAddSubject,
    required this.onDeleteSubject,
    required this.onSubjectTap,
    required this.onEditActivity,
    required this.onDeleteActivity,
    required this.isAddingSubject,
    required this.isDeletingSubject,
    required this.isEditingActivity,
    required this.isDeletingActivity,
    required this.pendingEntryTimeLabel,
    required this.onRefresh,
    required this.connectionState,
    required this.hasError,
    required this.subjectEntries,
    required this.onRetry,
  });

  final String selectedSemester;
  final bool isSelectedSemesterVisibleInSchedule;
  final bool isUpdatingSemesterVisibility;
  final ValueChanged<String> onSemesterChanged;
  final ValueChanged<bool> onScheduleVisibilityChanged;
  final Future<void> Function() onAddSubject;
  final Future<void> Function() onDeleteSubject;
  final ValueChanged<String> onSubjectTap;
  final Future<void> Function(String subjectName, SubjectScheduleEntry entry)
  onEditActivity;
  final Future<void> Function(String subjectName, SubjectScheduleEntry entry)
  onDeleteActivity;
  final bool isAddingSubject;
  final bool isDeletingSubject;
  final bool isEditingActivity;
  final bool isDeletingActivity;
  final String pendingEntryTimeLabel;
  final Future<void> Function() onRefresh;
  final ConnectionState connectionState;
  final bool hasError;
  final List<MapEntry<String, List<SubjectScheduleEntry>>> subjectEntries;
  final VoidCallback onRetry;

  @override
  State<SubjectsScreenView> createState() => _SubjectsScreenViewState();
}

class _SubjectsScreenViewState extends State<SubjectsScreenView> {
  bool _addButtonHovered = false;
  bool _deleteButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double bottomContentPadding =
        MediaQuery.viewPaddingOf(context).bottom +
        kBottomNavigationBarHeight +
        120;
    return Stack(
      children: [
        // Main content
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 60, 16, bottomContentPadding),
            children: <Widget>[
              // Modern semester selector
              _buildModernSemesterSelector(colors),
              const SizedBox(height: 12),
              _buildScheduleVisibilityToggle(colors),
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
                SubjectsLoadError(onRetry: widget.onRetry)
              else if (widget.subjectEntries.isEmpty)
                _SubjectsEmptyState(
                  colors: colors,
                  isSemesterVisibleInSchedule:
                      widget.isSelectedSemesterVisibleInSchedule,
                  selectedSemester: widget.selectedSemester,
                )
              else
                ...widget.subjectEntries.map(
                  (MapEntry<String, List<SubjectScheduleEntry>> entry) =>
                      _SubjectCard(
                        subjectName: entry.key,
                        entries: entry.value,
                        pendingEntryTimeLabel: widget.pendingEntryTimeLabel,
                        onTap: () => widget.onSubjectTap(entry.key),
                        onEditActivity: widget.onEditActivity,
                        onDeleteActivity: widget.onDeleteActivity,
                        isEditingActivity: widget.isEditingActivity,
                        isDeletingActivity: widget.isDeletingActivity,
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          _SemesterSelectorItem(
            label: 'Semestrul 1',
            icon: Icons.looks_one_rounded,
            selected: widget.selectedSemester == 'Semestrul 1',
            colors: colors,
            onTap: () => widget.onSemesterChanged('Semestrul 1'),
          ),
          const SizedBox(width: 6),
          _SemesterSelectorItem(
            label: 'Semestrul 2',
            icon: Icons.looks_two_rounded,
            selected: widget.selectedSemester == 'Semestrul 2',
            colors: colors,
            onTap: () => widget.onSemesterChanged('Semestrul 2'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleVisibilityToggle(ColorScheme colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.isSelectedSemesterVisibleInSchedule
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Vizibil in Orar',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isSelectedSemesterVisibleInSchedule
                          ? '${widget.selectedSemester} apare in orarul saptamanal.'
                          : '${widget.selectedSemester} este ascuns din orarul saptamanal.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.isSelectedSemesterVisibleInSchedule,
                onChanged: widget.isUpdatingSemesterVisibility
                    ? null
                    : widget.onScheduleVisibilityChanged,
              ),
            ],
          ),
        ),
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
                  colors: [
                    colors.primary,
                    colors.secondary.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(
                      alpha: _addButtonHovered ? 0.4 : 0.2,
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
                  onTap: widget.isAddingSubject ? null : widget.onAddSubject,
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
                        Flexible(
                          child: Text(
                            widget.isAddingSubject ? 'Se adauga...' : 'Adauga',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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
                    colors.error.withValues(alpha: 0.9),
                    colors.error.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colors.error.withValues(
                      alpha: _deleteButtonHovered ? 0.3 : 0.15,
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
                  onTap: widget.isDeletingSubject
                      ? null
                      : widget.onDeleteSubject,
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
                        Flexible(
                          child: Text(
                            widget.isDeletingSubject
                                ? 'Se sterge...'
                                : 'Sterge',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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
      ],
    );
  }
}

class SubjectsLoadError extends StatelessWidget {
  const SubjectsLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Nu s-au putut incarca materiile.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reincearca')),
        ],
      ),
    );
  }
}

class _SubjectsEmptyState extends StatelessWidget {
  const _SubjectsEmptyState({
    required this.colors,
    required this.isSemesterVisibleInSchedule,
    required this.selectedSemester,
  });

  final ColorScheme colors;
  final bool isSemesterVisibleInSchedule;
  final String selectedSemester;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.menu_book_rounded, color: colors.primary, size: 30),
          const SizedBox(height: 10),
          Text(
            'Nu ai materii in $selectedSemester',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isSemesterVisibleInSchedule
                ? 'Adauga prima materie si apoi completeaza cursurile, seminarele sau laboratoarele.'
                : 'Semestrul este ascuns din Orar. Il poti face vizibil din toggle-ul de mai sus.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SemesterSelectorItem extends StatelessWidget {
  const _SemesterSelectorItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    colors.primary,
                    colors.tertiary.withValues(alpha: 0.9),
                  ],
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? Colors.white
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    required this.subjectName,
    required this.entries,
    required this.pendingEntryTimeLabel,
    required this.onTap,
    required this.onEditActivity,
    required this.onDeleteActivity,
    required this.isEditingActivity,
    required this.isDeletingActivity,
  });

  final String subjectName;
  final List<SubjectScheduleEntry> entries;
  final String pendingEntryTimeLabel;
  final VoidCallback onTap;
  final Future<void> Function(String subjectName, SubjectScheduleEntry entry)
  onEditActivity;
  final Future<void> Function(String subjectName, SubjectScheduleEntry entry)
  onDeleteActivity;
  final bool isEditingActivity;
  final bool isDeletingActivity;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<SubjectScheduleEntry> detailedEntries = widget.entries
        .where(
          (SubjectScheduleEntry entry) =>
              entry.time != widget.pendingEntryTimeLabel,
        )
        .toList(growable: false);
    final int subjectCredits = widget.entries.isNotEmpty
        ? widget.entries.first.credits
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
                    colors.primary.withValues(alpha: 0.12),
                    colors.secondary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(
                      alpha: _isHovered ? 0.25 : 0.12,
                    ),
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
                                    colors.primary.withValues(alpha: 0.3),
                                    colors.secondary.withValues(alpha: 0.2),
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
                        if (detailedEntries.isEmpty)
                          Text(
                            'Apasa pentru a adauga activitatea, ziua, ora, sala si profesorul.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                          )
                        else
                          ...detailedEntries.map(
                            (SubjectScheduleEntry entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SubjectActivityTile(
                                entry: entry,
                                colors: colors,
                                isEditingActivity: widget.isEditingActivity,
                                isDeletingActivity: widget.isDeletingActivity,
                                onEdit: () => widget.onEditActivity(
                                  widget.subjectName,
                                  entry,
                                ),
                                onDelete: () => widget.onDeleteActivity(
                                  widget.subjectName,
                                  entry,
                                ),
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

class _SubjectActivityTile extends StatelessWidget {
  const _SubjectActivityTile({
    required this.entry,
    required this.colors,
    required this.isEditingActivity,
    required this.isDeletingActivity,
    required this.onEdit,
    required this.onDelete,
  });

  final SubjectScheduleEntry entry;
  final ColorScheme colors;
  final bool isEditingActivity;
  final bool isDeletingActivity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _ActivityTypeBadge(
                      label: entry.sessionType,
                      colors: colors,
                    ),
                    Text(
                      '${entry.weekdayLabel} | ${entry.time}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (entry.room.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 7),
                  _ActivityInfoLine(
                    icon: Icons.location_on_outlined,
                    text: entry.room.trim(),
                    colors: colors,
                  ),
                ],
                if (entry.professor.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  _ActivityInfoLine(
                    icon: Icons.person_outline_rounded,
                    text: entry.professor.trim(),
                    colors: colors,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: isEditingActivity ? null : onEdit,
                icon: Icon(Icons.edit_rounded, color: colors.primary, size: 19),
                tooltip: 'Editeaza',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              ),
              IconButton(
                onPressed: isDeletingActivity ? null : onDelete,
                icon: Icon(Icons.delete_rounded, color: colors.error, size: 19),
                tooltip: 'Sterge',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityTypeBadge extends StatelessWidget {
  const _ActivityTypeBadge({required this.label, required this.colors});

  final String label;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ActivityInfoLine extends StatelessWidget {
  const _ActivityInfoLine({
    required this.icon,
    required this.text,
    required this.colors,
  });

  final IconData icon;
  final String text;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 15, color: colors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
