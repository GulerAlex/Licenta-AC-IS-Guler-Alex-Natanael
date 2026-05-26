import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class SubjectNoteCardData {
  const SubjectNoteCardData({
    required this.subjectName,
    required this.gradesByType,
    required this.weightsByType,
    required this.average,
  });

  final String subjectName;
  final Map<String, double?> gradesByType;
  final Map<String, double?> weightsByType;
  final double? average;
}

class GradesScreenView extends StatefulWidget {
  const GradesScreenView({
    super.key,
    required this.subjectCards,
    required this.onRefresh,
    required this.allSubjectsValue,
    required this.selectedSubject,
    required this.subjectOptions,
    required this.onSubjectChanged,
    required this.totalSubjectsCount,
    required this.onEditTypeGrade,
    required this.onEditTypeWeights,
    required this.onResetTypeWeights,
  });

  final List<SubjectNoteCardData> subjectCards;
  final Future<void> Function() onRefresh;
  final String allSubjectsValue;
  final String selectedSubject;
  final List<String> subjectOptions;
  final ValueChanged<String> onSubjectChanged;
  final int totalSubjectsCount;
  final Future<void> Function(String subjectName, String courseType)
  onEditTypeGrade;
  final Future<void> Function(String subjectName) onEditTypeWeights;
  final Future<void> Function(String subjectName) onResetTypeWeights;

  @override
  State<GradesScreenView> createState() => _GradesScreenViewState();
}

class _GradesScreenViewState extends State<GradesScreenView> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Main content
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
            children: <Widget>[
              // Modern summary card with glass morphism
              _buildSummaryCard(colors),
              const SizedBox(height: 20),
              // Modern filter card
              _buildFilterCard(colors),
              const SizedBox(height: 20),
              // Content area
              if (widget.subjectCards.isEmpty && widget.totalSubjectsCount == 0)
                Center(
                  child: Text(
                    'Nu exista materii inca. Adauga din pagina Materii.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else if (widget.subjectCards.isEmpty)
                Center(
                  child: Text(
                    'Nu exista rezultate pentru filtrele selectate.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else
                ...widget.subjectCards.map(
                  (SubjectNoteCardData card) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SubjectNoteCard(
                      card: card,
                      onEditTypeGrade: widget.onEditTypeGrade,
                      onEditTypeWeights: widget.onEditTypeWeights,
                      onResetTypeWeights: widget.onResetTypeWeights,
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
                colors.primary.withOpacity(0.2),
                colors.secondary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.15),
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
                const SizedBox(height: 12),
                Text(
                  '${widget.totalSubjectsCount}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Materii sincronizate in timp real',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
                colors.secondary.withOpacity(0.15),
                colors.tertiary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.secondary.withOpacity(0.25),
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
    required this.onEditTypeGrade,
    required this.onEditTypeWeights,
    required this.onResetTypeWeights,
  });

  static const List<String> _courseTypes = <String>[
    'Curs',
    'Seminar',
    'Laborator',
  ];

  final SubjectNoteCardData card;
  final Future<void> Function(String subjectName, String courseType)
  onEditTypeGrade;
  final Future<void> Function(String subjectName) onEditTypeWeights;
  final Future<void> Function(String subjectName) onResetTypeWeights;

  @override
  State<_SubjectNoteCard> createState() => _SubjectNoteCardState();
}

class _SubjectNoteCardState extends State<_SubjectNoteCard> {
  bool _isHovered = false;

  String _formatWeights(Map<String, double?> weightsByType) {
    final List<String> parts = <String>[];

    for (final String courseType in _SubjectNoteCard._courseTypes) {
      final double? value = weightsByType[courseType];
      if (value == null) {
        continue;
      }

      final String formatted = (value % 1 == 0)
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
      parts.add('$courseType $formatted%');
    }

    if (parts.isEmpty) {
      return 'Ponderi: implicit (media aritmetica)';
    }

    return 'Ponderi: ${parts.join(' • ')}';
  }

  bool _hasWeights(Map<String, double?> weightsByType) {
    return weightsByType.values.any(
      (double? value) => value != null && value > 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.card.subjectName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary.withOpacity(0.35),
                              colors.secondary.withOpacity(0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.card.average == null
                              ? '-'
                              : widget.card.average!.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatWeights(widget.card.weightsByType),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () =>
                            widget.onEditTypeWeights(widget.card.subjectName),
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
                        onPressed: () =>
                            widget.onResetTypeWeights(widget.card.subjectName),
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
                  // Course types
                  ..._SubjectNoteCard._courseTypes.map(
                    (String courseType) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TypeGradeTile(
                        subjectName: widget.card.subjectName,
                        courseType: courseType,
                        grade: widget.card.gradesByType[courseType],
                        onEditTypeGrade: widget.onEditTypeGrade,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withOpacity(0.1),
                          colors.primary.withOpacity(0.3),
                          colors.primary.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Text(
                        _hasWeights(widget.card.weightsByType)
                            ? 'Media ponderata'
                            : 'Media aritmetica',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
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

class _TypeGradeTile extends StatelessWidget {
  const _TypeGradeTile({
    required this.subjectName,
    required this.courseType,
    required this.grade,
    required this.onEditTypeGrade,
  });

  final String subjectName;
  final String courseType;
  final double? grade;
  final Future<void> Function(String subjectName, String courseType)
  onEditTypeGrade;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onEditTypeGrade(subjectName, courseType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.secondary.withOpacity(0.15),
              colors.tertiary.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.secondary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.secondary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                courseType,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                grade == null
                    ? 'Adauga nota'
                    : 'Nota: ${grade!.toStringAsFixed(2)}',
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
