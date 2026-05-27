import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:unihub/models/academic_progress.dart';

class SubjectNoteCardData {
  const SubjectNoteCardData({
    required this.subjectName,
    required this.evaluation,
  });

  final String subjectName;
  final SubjectEvaluation evaluation;
}

class SemesterAverageData {
  const SemesterAverageData({
    required this.semesterLabel,
    required this.totalCredits,
    required this.earnedCredits,
    required this.average,
  });

  final String semesterLabel;
  final int totalCredits;
  final int earnedCredits;
  final double? average;
}

class GradesScreenView extends StatefulWidget {
  const GradesScreenView({
    super.key,
    required this.subjectCards,
    required this.totalCredits,
    required this.earnedCredits,
    required this.weightedAverage,
    required this.semesterAverages,
    required this.onRefresh,
    required this.allSubjectsValue,
    required this.selectedSubject,
    required this.subjectOptions,
    required this.onSubjectChanged,
    required this.totalSubjectsCount,
    required this.onEditComponentGrade,
    required this.onEditComponentWeights,
    required this.onResetComponentWeights,
  });

  final List<SubjectNoteCardData> subjectCards;
  final int totalCredits;
  final int earnedCredits;
  final double? weightedAverage;
  final List<SemesterAverageData> semesterAverages;
  final Future<void> Function() onRefresh;
  final String allSubjectsValue;
  final String selectedSubject;
  final List<String> subjectOptions;
  final ValueChanged<String> onSubjectChanged;
  final int totalSubjectsCount;
  final Future<void> Function(String subjectName, String componentName)
  onEditComponentGrade;
  final Future<void> Function(String subjectName) onEditComponentWeights;
  final Future<void> Function(String subjectName) onResetComponentWeights;

  @override
  State<GradesScreenView> createState() => _GradesScreenViewState();
}

class _GradesScreenViewState extends State<GradesScreenView> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double bottomContentPadding =
        MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 72;
    return Stack(
      children: [
        // Main content
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 60, 16, bottomContentPadding),
            children: <Widget>[
              // Modern summary card with glass morphism
              _buildSummaryCard(colors),
              const SizedBox(height: 20),
              // Modern filter card
              _buildFilterCard(colors),
              const SizedBox(height: 20),
              // Content area
              if (widget.subjectCards.isEmpty && widget.totalSubjectsCount == 0)
                _GradesEmptyState(
                  icon: Icons.menu_book_rounded,
                  title: 'Nu ai materii adaugate',
                  message:
                      'Adauga materiile din pagina Materii, apoi revino aici pentru note, credite si medii.',
                  colors: colors,
                )
              else if (widget.subjectCards.isEmpty)
                _GradesEmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'Nicio materie pentru filtrul ales',
                  message:
                      'Schimba filtrul pe Toate materiile sau selecteaza alta materie.',
                  colors: colors,
                )
              else
                ...widget.subjectCards.map(
                  (SubjectNoteCardData card) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SubjectNoteCard(
                      card: card,
                      onEditComponentGrade: widget.onEditComponentGrade,
                      onEditComponentWeights: widget.onEditComponentWeights,
                      onResetComponentWeights: widget.onResetComponentWeights,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(ColorScheme colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.2),
                colors.secondary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Medii pe materie',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    Icon(
                      Icons.trending_up_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _annualAveragePanel(colors),
                if (widget.semesterAverages.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < widget.semesterAverages.length;
                        index++
                      )
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == widget.semesterAverages.length - 1
                                  ? 0
                                  : 8,
                            ),
                            child: _semesterAverageMetric(
                              data: widget.semesterAverages[index],
                              index: index,
                              colors: colors,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Nota minima de promovare este 5. Creditele se obtin integral doar pentru materiile promovate.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _annualAveragePanel(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Media anuala',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.weightedAverage == null
                      ? '-'
                      : widget.weightedAverage!.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          _creditBadge(
            colors: colors,
            value: '${widget.earnedCredits}/${widget.totalCredits} credite',
          ),
        ],
      ),
    );
  }

  Widget _semesterAverageMetric({
    required SemesterAverageData data,
    required int index,
    required ColorScheme colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sem. ${index + 1}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  data.average == null ? '-' : data.average!.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              Text(
                '${data.earnedCredits}/${data.totalCredits}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditBadge({required ColorScheme colors, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildFilterCard(ColorScheme colors) {
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
                colors.secondary.withValues(alpha: 0.15),
                colors.tertiary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.secondary.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Filtre',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: widget.selectedSubject,
                  decoration: InputDecoration(
                    labelText: 'Materie',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.book_rounded, color: colors.primary),
                  ),
                  items: widget.subjectOptions
                      .map(
                        (String subject) => DropdownMenuItem<String>(
                          value: subject,
                          child: Text(
                            subject == widget.allSubjectsValue
                                ? 'Toate materiile'
                                : subject,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    widget.onSubjectChanged(value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Total materii: ${widget.totalSubjectsCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectNoteCard extends StatefulWidget {
  const _SubjectNoteCard({
    required this.card,
    required this.onEditComponentGrade,
    required this.onEditComponentWeights,
    required this.onResetComponentWeights,
  });

  final SubjectNoteCardData card;
  final Future<void> Function(String subjectName, String componentName)
  onEditComponentGrade;
  final Future<void> Function(String subjectName) onEditComponentWeights;
  final Future<void> Function(String subjectName) onResetComponentWeights;

  @override
  State<_SubjectNoteCard> createState() => _SubjectNoteCardState();
}

class _SubjectNoteCardState extends State<_SubjectNoteCard> {
  bool _isHovered = false;

  String _formatWeights(List<GradeComponent> components) {
    final List<String> parts = <String>[];

    for (final GradeComponent component in components) {
      if (component.weight <= 0) {
        continue;
      }

      final double value = component.weight * 100;
      final String formatted = (value % 1 == 0)
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
      parts.add('${component.name} $formatted%');
    }

    if (parts.isEmpty) {
      return 'Ponderi: neconfigurate';
    }

    return 'Ponderi: ${parts.join(', ')}';
  }

  String? _statusReason(SubjectEvaluation evaluation) {
    if (evaluation.failingComponents.isNotEmpty) {
      final String names = evaluation.failingComponents
          .map((GradeComponent component) => component.name)
          .join(', ');
      return 'Materia nu este promovata deoarece componenta $names este sub 5.';
    }

    if (evaluation.missingRequiredComponents.isNotEmpty) {
      final String names = evaluation.missingRequiredComponents
          .map((GradeComponent component) => component.name)
          .join(', ');
      return 'Materia este incompleta: lipseste nota la $names.';
    }

    return evaluation.configurationMessage;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final SubjectEvaluation evaluation = widget.card.evaluation;
    final AcademicSubject subject = evaluation.subject;
    final double? shownGrade =
        evaluation.finalGrade ?? evaluation.estimatedFinalGrade;
    final String? statusReason = _statusReason(evaluation);

    return MouseRegion(
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.card.subjectName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _StatusChip(card: widget.card),
                      const SizedBox(width: 8),
                      Text(
                        '${evaluation.earnedCredits}/${subject.credits} credite',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatWeights(subject.components),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (statusReason != null) ...<Widget>[
                    const SizedBox(height: 10),
                    _StatusReasonBox(
                      message: statusReason,
                      status: evaluation.status,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => widget.onEditComponentWeights(
                          widget.card.subjectName,
                        ),
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        label: Text(
                          'Ponderi',
                          style: TextStyle(color: colors.primary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => widget.onResetComponentWeights(
                          widget.card.subjectName,
                        ),
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: colors.secondary,
                        ),
                        label: Text(
                          'Reset',
                          style: TextStyle(color: colors.secondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Grade components
                  ...subject.components.map(
                    (GradeComponent component) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ComponentGradeTile(
                        subjectName: widget.card.subjectName,
                        component: component,
                        onEditComponentGrade: widget.onEditComponentGrade,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withValues(alpha: 0.1),
                          colors.primary.withValues(alpha: 0.3),
                          colors.primary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Media materiei',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        shownGrade == null
                            ? '-'
                            : shownGrade.toStringAsFixed(2),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _ComponentGradeTile extends StatelessWidget {
  const _ComponentGradeTile({
    required this.subjectName,
    required this.component,
    required this.onEditComponentGrade,
  });

  final String subjectName;
  final GradeComponent component;
  final Future<void> Function(String subjectName, String componentName)
  onEditComponentGrade;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onEditComponentGrade(subjectName, component.name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.secondary.withValues(alpha: 0.15),
              colors.tertiary.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.secondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.secondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                component.name,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                component.grade == null
                    ? 'Adauga nota'
                    : 'Nota: ${component.grade!.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Icon(Icons.edit_rounded, size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _GradesEmptyState extends StatelessWidget {
  const _GradesEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String message;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: colors.primary, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.card});

  final SubjectNoteCardData card;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final SubjectStatus status = card.evaluation.status;
    final Color color = switch (status) {
      SubjectStatus.promoted => colors.primary,
      SubjectStatus.failed => colors.error,
      SubjectStatus.incomplete => Colors.orange,
      SubjectStatus.notStarted => colors.onSurfaceVariant,
    };
    final String label = switch (status) {
      SubjectStatus.promoted => 'Promovata',
      SubjectStatus.failed => 'Restanta',
      SubjectStatus.incomplete => 'Incompleta',
      SubjectStatus.notStarted => 'Neinceputa',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusReasonBox extends StatelessWidget {
  const _StatusReasonBox({required this.message, required this.status});

  final String message;
  final SubjectStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color color = switch (status) {
      SubjectStatus.promoted => colors.primary,
      SubjectStatus.failed => colors.error,
      SubjectStatus.incomplete => Colors.orange,
      SubjectStatus.notStarted => colors.onSurfaceVariant,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

class GradesLoadError extends StatelessWidget {
  const GradesLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Nu s-au putut incarca notele.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reincearca')),
          ],
        ),
      ),
    );
  }
}
