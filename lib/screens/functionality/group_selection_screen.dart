import 'package:flutter/material.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/screens/ui/group_selection_screen_view.dart';

class GroupSelectionScreen extends StatefulWidget {
  const GroupSelectionScreen({super.key, required this.onSaveGroup});

  final Future<bool> Function(String groupCode) onSaveGroup;

  @override
  State<GroupSelectionScreen> createState() => _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends State<GroupSelectionScreen> {
  String? _selectedGroup;
  bool _isSaving = false;

  Future<void> _submit() async {
    final String? group = _selectedGroup;
    if (group == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final bool success = await widget.onSaveGroup(group);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am putut salva grupa. Incearca din nou.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Grupa $group a fost salvata.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecteaza grupa')),
      body: SafeArea(
        child: GroupSelectionScreenView(
          selectedGroup: _selectedGroup,
          isSaving: _isSaving,
          availableGroups: UniHubRepository.availableGroups,
          onSelectGroup: (String group) {
            setState(() {
              _selectedGroup = group;
            });
          },
          onSubmit: _submit,
        ),
      ),
    );
  }
}
