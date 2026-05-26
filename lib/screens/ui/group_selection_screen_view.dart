import 'package:flutter/material.dart';

class GroupSelectionScreenView extends StatelessWidget {
  const GroupSelectionScreenView({
    super.key,
    required this.selectedGroup,
    required this.isSaving,
    required this.availableGroups,
    required this.onSelectGroup,
    required this.onSubmit,
  });

  final String? selectedGroup;
  final bool isSaving;
  final List<String> availableGroups;
  final ValueChanged<String> onSelectGroup;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Alege grupa ta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orarul este sincronizat pe grupa. Toti utilizatorii din aceeasi grupa vad acelasi calendar.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableGroups
                        .map((String group) {
                          return ChoiceChip(
                            label: Text('Grupa $group'),
                            selected: selectedGroup == group,
                            onSelected: (_) => onSelectGroup(group),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (selectedGroup == null || isSaving)
                          ? null
                          : onSubmit,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(isSaving ? 'Se salveaza...' : 'Continua'),
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
