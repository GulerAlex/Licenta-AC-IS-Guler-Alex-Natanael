import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:unihub/data/app_preferences_store.dart';
import 'package:unihub/models/profile_stats.dart';
import 'package:unihub/models/user_profile.dart';

class ProfileScreenView extends StatefulWidget {
  const ProfileScreenView({
    super.key,
    required this.profile,
    required this.stats,
    required this.semesterStats,
    required this.isStatsLoading,
    required this.isSemesterStatsLoading,
    required this.hasStatsError,
    required this.isLoggingOut,
    required this.isUpdatingProfile,
    required this.isUpdatingGroup,
    required this.themePreference,
    required this.avatarColor,
    required this.onRefresh,
    required this.onLogout,
    required this.onEditProfile,
    required this.onChangeGroup,
    required this.onThemePreferenceChanged,
    required this.onAvatarColorChanged,
    required this.onExportAcademicData,
  });

  final UserProfile profile;
  final ProfileStats? stats;
  final Map<String, ProfileStats> semesterStats;
  final bool isStatsLoading;
  final bool isSemesterStatsLoading;
  final bool hasStatsError;
  final bool isLoggingOut;
  final bool isUpdatingProfile;
  final bool isUpdatingGroup;
  final AppThemePreference themePreference;
  final Color avatarColor;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onChangeGroup;
  final ValueChanged<AppThemePreference> onThemePreferenceChanged;
  final ValueChanged<Color> onAvatarColorChanged;
  final Future<void> Function() onExportAcademicData;

  @override
  State<ProfileScreenView> createState() => _ProfileScreenViewState();
}

class _ProfileScreenViewState extends State<ProfileScreenView> {
  static const List<Color> _avatarColorOptions = <Color>[
    Color(0xFF35B86F),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];

  bool _editButtonHovered = false;
  bool _groupButtonHovered = false;
  bool _logoutButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String subjectsValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.totalSubjects.toString() ?? '-');
    final String creditsValue = widget.isStatsLoading
        ? '...'
        : (widget.stats == null
              ? '-'
              : '${widget.stats!.earnedCredits}/${widget.stats!.totalCredits}');
    final String averageValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.overallAverage == null
              ? '-'
              : widget.stats!.overallAverage!.toStringAsFixed(2));
    final String failedCreditsValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.failedCredits.toString() ?? '-');
    final String incompleteCreditsValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.incompleteCredits.toString() ?? '-');
    final String promotedSubjectsValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.promotedSubjects.toString() ?? '-');
    final String failedSubjectsValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.failedSubjects.toString() ?? '-');
    final String incompleteSubjectsValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.incompleteSubjects.toString() ?? '-');
    final String standingValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.standingLabel ?? '-');

    return Stack(
      children: [
        // Main content
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              60,
              16,
              MediaQuery.paddingOf(context).bottom +
                  kBottomNavigationBarHeight +
                  72,
            ),
            children: <Widget>[
              // Profile header card with glass morphism
              _buildProfileHeader(colors),
              const SizedBox(height: 20),
              _buildPreferencesCard(colors),
              const SizedBox(height: 20),
              // Stats card
              _buildStatsCard(
                colors,
                subjectsValue,
                creditsValue,
                averageValue,
                failedCreditsValue,
                incompleteCreditsValue,
                standingValue,
                promotedSubjectsValue,
                failedSubjectsValue,
                incompleteSubjectsValue,
              ),
              const SizedBox(height: 20),
              _buildSemesterStatsCard(colors),
              const SizedBox(height: 20),
              _buildReminderCard(colors),
              const SizedBox(height: 20),
              // Action buttons
              _buildActionButtons(colors),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  Widget _buildProfileHeader(ColorScheme colors) {
    return _GlassPanel(
      borderRadius: 20,
      borderColor: colors.primary.withValues(alpha: 0.3),
      gradientColors: <Color>[
        colors.primary.withValues(alpha: 0.2),
        colors.secondary.withValues(alpha: 0.1),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    widget.avatarColor,
                    widget.avatarColor.withValues(alpha: 0.72),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.avatarColor.withValues(alpha: 0.34),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _initials(widget.profile.fullName),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.profile.fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.profile.academicInfo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.profile.universityEmail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  if (widget.profile.groupCode != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.tertiary.withValues(alpha: 0.3),
                            colors.tertiary.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Grupa: ${widget.profile.groupCode}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(ColorScheme colors) {
    return _GlassPanel(
      borderRadius: 18,
      borderColor: colors.primary.withValues(alpha: 0.22),
      gradientColors: <Color>[
        colors.primary.withValues(alpha: 0.14),
        colors.secondary.withValues(alpha: 0.08),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Preferinte',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.tune_rounded, color: colors.primary),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Tema aplicatiei',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AppThemePreference>(
              segments: AppThemePreference.values
                  .map(
                    (AppThemePreference preference) =>
                        ButtonSegment<AppThemePreference>(
                          value: preference,
                          label: Text(preference.label),
                          icon: Icon(switch (preference) {
                            AppThemePreference.system =>
                              Icons.brightness_auto_rounded,
                            AppThemePreference.light =>
                              Icons.light_mode_rounded,
                            AppThemePreference.dark => Icons.dark_mode_rounded,
                          }, size: 18),
                        ),
                  )
                  .toList(growable: false),
              selected: <AppThemePreference>{widget.themePreference},
              onSelectionChanged: (Set<AppThemePreference> selection) {
                widget.onThemePreferenceChanged(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Culoare avatar',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _avatarColorOptions
                  .map((Color color) {
                    final bool selected =
                        color.toARGB32() == widget.avatarColor.toARGB32();
                    return InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => widget.onAvatarColorChanged(color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? colors.onSurface : Colors.white24,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    ColorScheme colors,
    String subjectsValue,
    String creditsValue,
    String averageValue,
    String failedCreditsValue,
    String incompleteCreditsValue,
    String standingValue,
    String promotedSubjectsValue,
    String failedSubjectsValue,
    String incompleteSubjectsValue,
  ) {
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
                colors.secondary.withValues(alpha: 0.15),
                colors.tertiary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rezumat academic',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Icon(
                      Icons.bar_chart_rounded,
                      color: colors.secondary,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.isStatsLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _StatItem(
                            label: 'Media generala',
                            value: averageValue,
                            icon: Icons.trending_up_rounded,
                            colors: colors,
                          ),
                          const SizedBox(width: 12),
                          _StatItem(
                            label: 'Credite obtinute',
                            value: creditsValue,
                            icon: Icons.school_rounded,
                            colors: colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _StatItem(
                            label: 'Credite restante',
                            value: failedCreditsValue,
                            icon: Icons.warning_rounded,
                            colors: colors,
                          ),
                          const SizedBox(width: 12),
                          _StatItem(
                            label: 'Materii promovate',
                            value: '$promotedSubjectsValue/$subjectsValue',
                            icon: Icons.verified_rounded,
                            colors: colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _StatItem(
                            label: 'Materii restante',
                            value: failedSubjectsValue,
                            icon: Icons.warning_rounded,
                            colors: colors,
                          ),
                          const SizedBox(width: 12),
                          _StatItem(
                            label: 'Materii incomplete',
                            value: incompleteSubjectsValue,
                            icon: Icons.pending_actions_rounded,
                            colors: colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _StatItem(
                            label: 'Credite incomplete',
                            value: incompleteCreditsValue,
                            icon: Icons.rule_rounded,
                            colors: colors,
                          ),
                          const SizedBox(width: 12),
                          _StatItem(
                            label: 'Status',
                            value: standingValue,
                            icon: Icons.school_rounded,
                            colors: colors,
                          ),
                        ],
                      ),
                    ],
                  ),
                if (widget.hasStatsError) ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => widget.onRefresh(),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      label: Text(
                        'Reincarca statisticile',
                        style: TextStyle(color: colors.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterStatsCard(ColorScheme colors) {
    return _GlassPanel(
      borderRadius: 18,
      borderColor: colors.secondary.withValues(alpha: 0.25),
      gradientColors: <Color>[
        colors.secondary.withValues(alpha: 0.14),
        colors.tertiary.withValues(alpha: 0.08),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Pe semestre',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.view_week_rounded, color: colors.secondary),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.isSemesterStatsLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...widget.semesterStats.entries.map(
                (MapEntry<String, ProfileStats> entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SemesterStatsRow(
                    semesterLabel: entry.key,
                    stats: entry.value,
                    colors: colors,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_AcademicReminderData> _academicReminders() {
    final ProfileStats? stats = widget.stats;
    if (stats == null) {
      return const <_AcademicReminderData>[];
    }

    final List<_AcademicReminderData> reminders = <_AcademicReminderData>[];
    if (stats.incompleteSubjects > 0) {
      reminders.add(
        _AcademicReminderData(
          icon: Icons.pending_actions_rounded,
          title: '${stats.incompleteSubjects} materii fara toate notele',
          subtitle: 'Completeaza notele lipsa ca media sa devina oficiala.',
        ),
      );
    }
    if (stats.failedSubjects > 0) {
      reminders.add(
        _AcademicReminderData(
          icon: Icons.warning_rounded,
          title: '${stats.failedSubjects} materii restante',
          subtitle: '${stats.failedCredits} credite sunt in zona de risc.',
        ),
      );
    }
    if (stats.notStartedSubjects > 0) {
      reminders.add(
        _AcademicReminderData(
          icon: Icons.edit_note_rounded,
          title: '${stats.notStartedSubjects} materii fara note introduse',
          subtitle: 'Adauga notele imediat ce apar rezultatele.',
        ),
      );
    }
    if (stats.totalSubjects > 0 &&
        stats.failedSubjects == 0 &&
        stats.incompleteSubjects == 0 &&
        stats.notStartedSubjects == 0) {
      reminders.add(
        const _AcademicReminderData(
          icon: Icons.check_circle_rounded,
          title: 'Nu ai remindere academice active',
          subtitle: 'Toate materiile au date complete pentru calcul.',
        ),
      );
    }
    if (stats.totalSubjects == 0) {
      reminders.add(
        const _AcademicReminderData(
          icon: Icons.menu_book_rounded,
          title: 'Adauga materiile pentru remindere',
          subtitle: 'Reminderele apar dupa ce exista cursuri si note.',
        ),
      );
    }

    return reminders;
  }

  Widget _buildReminderCard(ColorScheme colors) {
    final List<_AcademicReminderData> reminders = _academicReminders();
    return _GlassPanel(
      borderRadius: 18,
      borderColor: colors.primary.withValues(alpha: 0.22),
      gradientColors: <Color>[
        colors.primary.withValues(alpha: 0.12),
        colors.secondary.withValues(alpha: 0.08),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Remindere academice',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.notifications_active_rounded, color: colors.primary),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.isStatsLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...reminders.map(
                (_AcademicReminderData reminder) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AcademicReminderTile(
                    reminder: reminder,
                    colors: colors,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colors) {
    return Column(
      children: [
        // Edit and Change Group buttons
        Row(
          children: <Widget>[
            Expanded(
              child: MouseRegion(
                onEnter: (_) => setState(() => _editButtonHovered = true),
                onExit: (_) => setState(() => _editButtonHovered = false),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.secondary,
                        colors.tertiary.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.secondary.withValues(
                          alpha: _editButtonHovered ? 0.35 : 0.15,
                        ),
                        blurRadius: _editButtonHovered ? 18 : 10,
                        offset: const Offset(0, 8),
                        spreadRadius: _editButtonHovered ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.isUpdatingProfile
                          ? null
                          : widget.onEditProfile,
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
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isUpdatingProfile
                                  ? 'Se salveaza...'
                                  : 'Editeaza profil',
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
            Expanded(
              child: MouseRegion(
                onEnter: (_) => setState(() => _groupButtonHovered = true),
                onExit: (_) => setState(() => _groupButtonHovered = false),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(alpha: 0.85),
                        colors.primary.withValues(alpha: 0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(
                          alpha: _groupButtonHovered ? 0.25 : 0.1,
                        ),
                        blurRadius: _groupButtonHovered ? 16 : 8,
                        offset: const Offset(0, 6),
                        spreadRadius: _groupButtonHovered ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.isUpdatingGroup
                          ? null
                          : widget.onChangeGroup,
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
                              Icons.group_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isUpdatingGroup
                                  ? 'Se salveaza...'
                                  : 'Schimba grupa',
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
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onExportAcademicData,
            icon: Icon(Icons.file_download_rounded, color: colors.primary),
            label: Text(
              'Exporta date CSV',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Logout button
        MouseRegion(
          onEnter: (_) => setState(() => _logoutButtonHovered = true),
          onExit: (_) => setState(() => _logoutButtonHovered = false),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.error, colors.error.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colors.error.withValues(
                    alpha: _logoutButtonHovered ? 0.35 : 0.15,
                  ),
                  blurRadius: _logoutButtonHovered ? 18 : 10,
                  offset: const Offset(0, 8),
                  spreadRadius: _logoutButtonHovered ? 2 : 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoggingOut ? null : widget.onLogout,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.isLoggingOut
                            ? 'Se deconecteaza...'
                            : 'Deconectare',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
      ],
    );
  }
}

class ProfileLoadError extends StatelessWidget {
  const ProfileLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Nu s-a putut incarca profilul.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reincearca')),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.15),
              colors.secondary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, size: 16, color: colors.primary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterStatsRow extends StatelessWidget {
  const _SemesterStatsRow({
    required this.semesterLabel,
    required this.stats,
    required this.colors,
  });

  final String semesterLabel;
  final ProfileStats stats;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final String average = stats.overallAverage == null
        ? '-'
        : stats.overallAverage!.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  semesterLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.promotedSubjects} promovate | ${stats.failedSubjects} restante | ${stats.incompleteSubjects} incomplete',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stats.earnedCredits}/${stats.totalCredits} credite',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                average,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                stats.standingLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcademicReminderData {
  const _AcademicReminderData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _AcademicReminderTile extends StatelessWidget {
  const _AcademicReminderTile({required this.reminder, required this.colors});

  final _AcademicReminderData reminder;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(reminder.icon, color: colors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reminder.title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  reminder.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    required this.borderColor,
    required this.gradientColors,
  });

  final Widget child;
  final double borderRadius;
  final Color borderColor;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
