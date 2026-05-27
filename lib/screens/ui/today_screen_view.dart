import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:unihub/models/academic_event.dart';
import 'package:unihub/models/today_overview.dart';

class TodayScreenView extends StatelessWidget {
  const TodayScreenView({
    super.key,
    required this.overview,
    required this.connectionState,
    required this.hasError,
    required this.onRefresh,
    required this.onRetry,
    required this.onOpenSchedule,
    required this.onOpenSubjects,
  });

  final TodayOverview? overview;
  final ConnectionState connectionState;
  final bool hasError;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenSubjects;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isLoading = connectionState == ConnectionState.waiting;
    final double bottomContentPadding =
        MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 120;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 60, 16, bottomContentPadding),
        children: <Widget>[
          Text(
            'Astazi',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _formatToday(DateTime.now()),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            _StateCard(
              icon: Icons.cloud_off_rounded,
              title: 'Nu am putut incarca datele',
              message:
                  'Verifica conexiunea si incearca din nou. Daca problema continua, datele academice nu sunt disponibile momentan.',
              action: FilledButton(
                onPressed: onRetry,
                child: const Text('Reincearca'),
              ),
            )
          else if (overview == null || !overview!.hasAnyData)
            _StateCard(
              icon: Icons.dashboard_customize_rounded,
              title: 'Pregateste-ti dashboard-ul',
              message:
                  'Adauga materiile si activitatile din orar ca sa vezi aici cursurile de azi, examenele apropiate si riscurile la note.',
              action: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: onOpenSubjects,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Adauga materii'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenSchedule,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Deschide orarul'),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            _NextClassCard(item: overview!.nextClass),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Cursurile de azi',
              icon: Icons.schedule_rounded,
              emptyText: 'Nu ai cursuri programate azi.',
              children: overview!.todayClasses
                  .map((TodayClassItem item) => _ClassTile(item: item))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Urmeaza',
              icon: Icons.event_available_rounded,
              emptyText: 'Nu ai examene sau deadline-uri apropiate.',
              children: overview!.upcomingEvents
                  .map((TodayEventItem item) => _EventTile(item: item))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Task-uri deschise',
              icon: Icons.task_alt_rounded,
              emptyText: 'Nu ai task-uri active.',
              children: overview!.openTasks
                  .map((TodayTaskItem item) => _TaskTile(item: item))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Atentie',
              icon: Icons.warning_amber_rounded,
              emptyText: 'Nu sunt riscuri academice evidente.',
              children: overview!.risks
                  .map((TodayRiskItem item) => _RiskTile(item: item))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.item});

  final TodayClassItem? item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TodayClassItem? classItem = item;

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.near_me_rounded, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Urmatorul curs',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  classItem == null
                      ? 'Nu mai ai cursuri azi'
                      : classItem.subject.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (classItem != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${classItem.session.sessionType} • ${classItem.session.intervalLabel}'
                    '${classItem.session.room.isEmpty ? '' : ' • ${classItem.session.room}'}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 19, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Text(
              emptyText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.item});

  final TodayClassItem item;

  @override
  Widget build(BuildContext context) {
    return _DenseTile(
      title: item.subject.name,
      subtitle:
          '${item.session.sessionType} • ${item.session.intervalLabel}'
          '${item.session.room.isEmpty ? '' : ' • ${item.session.room}'}',
      trailing: _weekdayLabel(item.session.weekday),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.item});

  final TodayEventItem item;

  @override
  Widget build(BuildContext context) {
    final DateTime? date = item.event.effectiveDate;
    return _DenseTile(
      title: item.event.title,
      subtitle:
          '${item.event.type.label}${item.subject == null ? '' : ' • ${item.subject!.name}'}',
      trailing: date == null ? '-' : _formatCompactDate(date),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.item});

  final TodayTaskItem item;

  @override
  Widget build(BuildContext context) {
    final DateTime? dueAt = item.task.dueAt;
    return _DenseTile(
      title: item.task.title,
      subtitle:
          '${_priorityLabel(item.task.priority)}${item.subject == null ? '' : ' • ${item.subject!.name}'}',
      trailing: dueAt == null ? '-' : _formatCompactDate(dueAt),
    );
  }
}

class _RiskTile extends StatelessWidget {
  const _RiskTile({required this.item});

  final TodayRiskItem item;

  @override
  Widget build(BuildContext context) {
    return _DenseTile(
      title: item.subject.name,
      subtitle: item.message,
      trailing: item.severity == TodayRiskSeverity.high ? 'Risc mare' : 'Risc',
    );
  }
}

class _DenseTile extends StatelessWidget {
  const _DenseTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 34, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...<Widget>[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: 0.12),
                colors.secondary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.08),
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

String _formatToday(DateTime date) {
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
    'ianuarie',
    'februarie',
    'martie',
    'aprilie',
    'mai',
    'iunie',
    'iulie',
    'august',
    'septembrie',
    'octombrie',
    'noiembrie',
    'decembrie',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

String _formatCompactDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}';
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
    _ => '-',
  };
}

String _priorityLabel(AcademicPriority priority) {
  return switch (priority) {
    AcademicPriority.low => 'Prioritate scazuta',
    AcademicPriority.medium => 'Prioritate medie',
    AcademicPriority.high => 'Prioritate ridicata',
  };
}
