import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:unihub/models/profile_stats.dart';
import 'package:unihub/models/user_profile.dart';

class ProfileScreenView extends StatefulWidget {
  const ProfileScreenView({
    super.key,
    required this.profile,
    required this.stats,
    required this.isStatsLoading,
    required this.hasStatsError,
    required this.isLoggingOut,
    required this.isUpdatingProfile,
    required this.isUpdatingGroup,
    required this.onRefresh,
    required this.onLogout,
    required this.onEditProfile,
    required this.onChangeGroup,
  });

  final UserProfile profile;
  final ProfileStats? stats;
  final bool isStatsLoading;
  final bool hasStatsError;
  final bool isLoggingOut;
  final bool isUpdatingProfile;
  final bool isUpdatingGroup;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onChangeGroup;

  @override
  State<ProfileScreenView> createState() => _ProfileScreenViewState();
}

class _ProfileScreenViewState extends State<ProfileScreenView> {
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
        : (widget.stats?.totalCredits.toString() ?? '-');
    final String averageValue = widget.isStatsLoading
        ? '...'
        : (widget.stats?.overallAverage == null
              ? '-'
              : widget.stats!.overallAverage!.toStringAsFixed(2));

    return Stack(
      children: [
        // Main content
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
            children: <Widget>[
              // Profile header card with glass morphism
              _buildProfileHeader(colors),
              const SizedBox(height: 20),
              // Stats card
              _buildStatsCard(
                colors,
                subjectsValue,
                creditsValue,
                averageValue,
              ),
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

  Widget _buildProfileHeader(ColorScheme colors) {
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
                      colors: [
                        colors.primary,
                        colors.secondary.withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: Colors.white,
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
                          color: colors.onSurfaceVariant.withOpacity(0.7),
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
                                colors.tertiary.withOpacity(0.3),
                                colors.tertiary.withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Grupa: ${widget.profile.groupCode}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
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
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    ColorScheme colors,
    String subjectsValue,
    String creditsValue,
    String averageValue,
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
                colors.secondary.withOpacity(0.15),
                colors.tertiary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Statistici rapide',
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
                  Row(
                    children: <Widget>[
                      _StatItem(
                        label: 'Materii',
                        value: subjectsValue,
                        icon: Icons.book_rounded,
                        colors: colors,
                      ),
                      const SizedBox(width: 12),
                      _StatItem(
                        label: 'Credite',
                        value: creditsValue,
                        icon: Icons.school_rounded,
                        colors: colors,
                      ),
                      const SizedBox(width: 12),
                      _StatItem(
                        label: 'Medie',
                        value: averageValue,
                        icon: Icons.trending_up_rounded,
                        colors: colors,
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
                        colors.tertiary.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.secondary.withOpacity(
                          _editButtonHovered ? 0.35 : 0.15,
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
                        colors.primary.withOpacity(0.85),
                        colors.primary.withOpacity(0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withOpacity(
                          _groupButtonHovered ? 0.25 : 0.1,
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
        // Logout button
        MouseRegion(
          onEnter: (_) => setState(() => _logoutButtonHovered = true),
          onExit: (_) => setState(() => _logoutButtonHovered = false),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.error, colors.error.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colors.error.withOpacity(
                    _logoutButtonHovered ? 0.35 : 0.15,
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
              colors.primary.withOpacity(0.15),
              colors.secondary.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary.withOpacity(0.2), width: 1),
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
