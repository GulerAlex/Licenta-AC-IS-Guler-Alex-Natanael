import 'package:flutter/material.dart';
import 'package:unihub/screens/ui/noise_overlay.dart';

class AcademicSetupScreenView extends StatelessWidget {
  const AcademicSetupScreenView({
    super.key,
    required this.formKey,
    required this.facultyController,
    required this.selectedStudyYear,
    required this.selectedGroup,
    required this.isSaving,
    required this.facultyOptions,
    required this.groupOptions,
    required this.onFacultySelected,
    required this.onStudyYearSelected,
    required this.onGroupSelected,
    required this.onSubmit,
    required this.onSkip,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController facultyController;
  final int? selectedStudyYear;
  final String? selectedGroup;
  final bool isSaving;
  final List<String> facultyOptions;
  final List<String> groupOptions;
  final ValueChanged<String> onFacultySelected;
  final ValueChanged<int> onStudyYearSelected;
  final ValueChanged<String> onGroupSelected;
  final Future<void> Function() onSubmit;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Stack(
      children: <Widget>[
        const GrainBackground(),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                color: colors.surface.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Configureaza profilul de student',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Alege facultatea, anul si grupa ca aplicatia sa poata organiza orarul si progresul academic.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: facultyController,
                          decoration: const InputDecoration(
                            labelText: 'Facultate',
                            helperText: 'Alege o sugestie sau scrie manual.',
                          ),
                          validator: (String? value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Facultatea este obligatorie.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: facultyOptions
                              .map(
                                (String faculty) => ActionChip(
                                  label: Text(faculty),
                                  onPressed: () => onFacultySelected(faculty),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'An de studiu',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List<Widget>.generate(4, (int index) {
                            final int year = index + 1;
                            return ChoiceChip(
                              label: Text('Anul $year'),
                              selected: selectedStudyYear == year,
                              onSelected: (_) => onStudyYearSelected(year),
                            );
                          }),
                        ),
                        if (selectedStudyYear == null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'Selecteaza anul de studiu.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.error),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          'Grupa',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: groupOptions
                              .map(
                                (String group) => ChoiceChip(
                                  label: Text('Grupa $group'),
                                  selected: selectedGroup == group,
                                  onSelected: (_) => onGroupSelected(group),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        if (selectedGroup == null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'Selecteaza grupa.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.error),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isSaving ? null : onSubmit,
                            icon: const Icon(Icons.school_rounded),
                            label: Text(
                              isSaving ? 'Se salveaza...' : 'Continua',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: isSaving ? null : onSkip,
                            child: const Text('Completez mai tarziu'),
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
