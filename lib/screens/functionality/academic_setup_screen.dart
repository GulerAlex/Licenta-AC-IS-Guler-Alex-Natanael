import 'package:flutter/material.dart';
import 'package:unihub/screens/ui/academic_setup_screen_view.dart';

class AcademicSetupScreen extends StatefulWidget {
  const AcademicSetupScreen({super.key, required this.onSaveAcademicDetails});

  final Future<bool> Function({required String faculty, required int studyYear})
  onSaveAcademicDetails;

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
    if (!isFormValid || studyYear == null) {
      setState(() {});
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final bool success = await widget.onSaveAcademicDetails(
      faculty: _facultyController.text.trim(),
      studyYear: studyYear,
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
      appBar: AppBar(title: const Text('Profil academic')),
      body: SafeArea(
        child: AcademicSetupScreenView(
          formKey: _formKey,
          facultyController: _facultyController,
          selectedStudyYear: _selectedStudyYear,
          isSaving: _isSaving,
          facultyOptions: _facultyOptions,
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
          onSubmit: _submit,
        ),
      ),
    );
  }
}
