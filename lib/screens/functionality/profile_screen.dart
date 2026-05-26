import 'package:flutter/material.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/profile_stats.dart';
import 'package:unihub/models/user_profile.dart';
import 'package:unihub/screens/ui/profile_screen_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UniHubRepository _repository = UniHubRepository.instance;
  late Future<UserProfile> _profileFuture;
  late Future<ProfileStats> _statsFuture;
  bool _isLoggingOut = false;
  bool _isUpdatingProfile = false;
  bool _isUpdatingGroup = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repository.fetchProfile();
    _statsFuture = _repository.fetchProfileStats();
  }

  Future<void> _reload() async {
    setState(() {
      _profileFuture = _repository.fetchProfile();
      _statsFuture = _repository.fetchProfileStats();
    });
    await Future.wait(<Future<dynamic>>[_profileFuture, _statsFuture]);
  }

  int? _parseStudyYear(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 1 || parsed > 4) {
      return null;
    }
    return parsed;
  }

  Future<void> _openEditProfileDialog(UserProfile profile) async {
    if (_isUpdatingProfile) {
      return;
    }

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController(
      text: profile.fullName,
    );
    final TextEditingController facultyController = TextEditingController(
      text: profile.faculty,
    );
    final TextEditingController yearController = TextEditingController(
      text: profile.studyYear?.toString() ?? '',
    );
    final TextEditingController emailController = TextEditingController(
      text: profile.universityEmail,
    );

    final _ProfileEditDraft? draft = await showDialog<_ProfileEditDraft>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Editeaza profilul'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nume complet',
                      ),
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Numele este obligatoriu.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: facultyController,
                      decoration: const InputDecoration(
                        labelText: 'Facultate',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'An de studiu (1-4)',
                      ),
                      validator: (String? value) {
                        final String trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) {
                          return null;
                        }
                        final int? parsed = int.tryParse(trimmed);
                        if (parsed == null || parsed < 1 || parsed > 4) {
                          return 'Introdu un an valid (1-4).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email universitar',
                      ),
                      validator: (String? value) {
                        final String email = (value ?? '').trim();
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Email invalid.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Renunta'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                Navigator.of(dialogContext).pop(
                  _ProfileEditDraft(
                    fullName: nameController.text,
                    faculty: facultyController.text,
                    studyYear: _parseStudyYear(yearController.text),
                    universityEmail: emailController.text,
                  ),
                );
              },
              child: const Text('Salveaza'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    facultyController.dispose();
    yearController.dispose();
    emailController.dispose();

    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _isUpdatingProfile = true;
    });

    try {
      await _repository.updateProfile(
        fullName: draft.fullName,
        faculty: draft.faculty,
        studyYear: draft.studyYear,
        universityEmail: draft.universityEmail,
      );
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilul a fost actualizat.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu am putut salva profilul.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }

  Future<void> _openChangeGroupDialog(String? currentGroup) async {
    if (_isUpdatingGroup) {
      return;
    }

    final List<String> groups = UniHubRepository.availableGroups;
    String selectedGroup = groups.first;
    if (currentGroup != null && groups.contains(currentGroup)) {
      selectedGroup = currentGroup;
    }

    final String? newGroup = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return AlertDialog(
                  title: const Text('Schimba grupa'),
                  content: DropdownButtonFormField<String>(
                    initialValue: selectedGroup,
                    decoration: const InputDecoration(labelText: 'Grupa'),
                    items: groups
                        .map(
                          (String group) => DropdownMenuItem<String>(
                            value: group,
                            child: Text('Grupa $group'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selectedGroup = value;
                      });
                    },
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Renunta'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(selectedGroup),
                      child: const Text('Salveaza'),
                    ),
                  ],
                );
              },
        );
      },
    );

    if (!mounted || newGroup == null || newGroup == currentGroup) {
      return;
    }

    setState(() {
      _isUpdatingGroup = true;
    });

    try {
      await _repository.setCurrentGroupCode(newGroup);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Grupa $newGroup a fost salvata.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu am putut salva grupa.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingGroup = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    await widget.onLogout();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _profileFuture,
      builder: (BuildContext context, AsyncSnapshot<UserProfile> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return ProfileLoadError(onRetry: _reload);
        }

        return FutureBuilder<ProfileStats>(
          future: _statsFuture,
          builder:
              (BuildContext context, AsyncSnapshot<ProfileStats> stats) {
                return ProfileScreenView(
                  profile: snapshot.data!,
                  stats: stats.data,
                  isStatsLoading:
                      stats.connectionState == ConnectionState.waiting,
                  hasStatsError: stats.hasError,
                  isLoggingOut: _isLoggingOut,
                  isUpdatingProfile: _isUpdatingProfile,
                  isUpdatingGroup: _isUpdatingGroup,
                  onRefresh: _reload,
                  onLogout: _logout,
                  onEditProfile: () => _openEditProfileDialog(snapshot.data!),
                  onChangeGroup: () =>
                      _openChangeGroupDialog(snapshot.data!.groupCode),
                );
              },
        );
      },
    );
  }
}

class _ProfileEditDraft {
  const _ProfileEditDraft({
    required this.fullName,
    required this.faculty,
    required this.studyYear,
    required this.universityEmail,
  });

  final String fullName;
  final String faculty;
  final int? studyYear;
  final String universityEmail;
}
