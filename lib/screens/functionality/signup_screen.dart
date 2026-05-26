import 'package:flutter/material.dart';
import 'package:unihub/screens/ui/signup_screen_view.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.onSignUp});

  final Future<bool> Function(
    String email,
    String password,
    String nume,
    String prenume,
  )
  onSignUp;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _numeController = TextEditingController();
  final TextEditingController _prenumeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _numeController.dispose();
    _prenumeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      return 'Email valid obligatoriu';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) {
      return '$fieldName este obligatoriu';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Parola trebuie sa aiba cel putin 6 caractere';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String nume = _numeController.text;
    final String prenume = _prenumeController.text;
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
    });

    final bool success = await widget.onSignUp(email, password, nume, prenume);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inregistrarea a esuat. Incearca alt email sau incearca din nou.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SignUpScreenView(
          formKey: _formKey,
          numeController: _numeController,
          prenumeController: _prenumeController,
          emailController: _emailController,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          isSubmitting: _isSubmitting,
          onTogglePassword: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          onSubmit: _submit,
          emailValidator: _validateEmail,
          numeValidator: (String? value) => _validateRequired(value, 'Nume'),
          prenumeValidator: (String? value) =>
              _validateRequired(value, 'Prenume'),
          passwordValidator: _validatePassword,
        ),
      ),
    );
  }
}
