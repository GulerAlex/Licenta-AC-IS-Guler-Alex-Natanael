import 'package:flutter/material.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/screens/ui/academic_setup_screen_view.dart';

class AcademicSetupScreen extends StatefulWidget {
  const AcademicSetupScreen({
    super.key,
    required this.onSaveAcademicOnboarding,
    required this.onSkip,
  });

  final Future<bool> Function({
    required String faculty,
    required int studyYear,
    required String groupCode,
  })
  onSaveAcademicOnboarding;
  final VoidCallback onSkip;

  @override
  State<AcademicSetupScreen> createState() => _AcademicSetupScreenState();
}

class _AcademicSetupScreenState extends State<AcademicSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _facultyController = TextEditingController();

  static const List<String> _facultyOptions = <String>[
    'Automatica si Calculatoare',
    'Electronica si Telecomunicatii',
    'Matematica si Informatica',
    'Stiinte Economice',
    'Drept',
    'Medicina',
  ];

  int? _selectedStudyYear;
  String? _selectedGroup;
  bool _isSaving = false;

  @override
  void dispose() {
    _facultyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    final int? studyYear = _selectedStudyYear;
    final String? group = _selectedGroup;
    if (!isFormValid || studyYear == null || group == null) {
      setState(() {});
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final bool success = await widget.onSaveAcademicOnboarding(
      faculty: _facultyController.text.trim(),
      studyYear: studyYear,
      groupCode: group,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nu am putut salva profilul academic. Incearca din nou.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profilul academic a fost salvat.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurare student'),
        actions: <Widget>[
          TextButton(onPressed: widget.onSkip, child: const Text('Mai tarziu')),
        ],
      ),
      body: SafeArea(
        child: AcademicSetupScreenView(
          formKey: _formKey,
          facultyController: _facultyController,
          selectedStudyYear: _selectedStudyYear,
          selectedGroup: _selectedGroup,
          isSaving: _isSaving,
          facultyOptions: _facultyOptions,
          groupOptions: UniHubRepository.availableGroups,
          onFacultySelected: (String faculty) {
            setState(() {
              _facultyController.text = faculty;
            });
          },
          onStudyYearSelected: (int year) {
            setState(() {
              _selectedStudyYear = year;
            });
          },
          onGroupSelected: (String group) {
            setState(() {
              _selectedGroup = group;
            });
          },
          onSubmit: _submit,
          onSkip: widget.onSkip,
        ),
      ),
    );
  }
}
