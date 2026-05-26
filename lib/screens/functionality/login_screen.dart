import 'package:flutter/material.dart';
import 'package:unihub/screens/ui/login_screen_view.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onOpenSignUp,
  });

  final Future<bool> Function(String email, String password) onLogin;
  final Future<String?> Function() onOpenSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _rememberMe = false;

  @override
  void dispose() {
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

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Parola este obligatorie';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    bool success = false;
    try {
      success = await widget.onLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (_) {
      success = false;
    }

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
            'Autentificarea a esuat. Verifica datele si conexiunea.',
          ),
        ),
      );
    }
  }

  Future<void> _goToSignUp() async {
    final String? newEmail = await widget.onOpenSignUp();
    if (newEmail != null && mounted) {
      _emailController.text = newEmail;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cont creat. Acum te poti autentifica.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LoginScreenView(
          formKey: _formKey,
          emailController: _emailController,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          isSubmitting: _isSubmitting,
          rememberMe: _rememberMe,
          onTogglePassword: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          onRememberMeChanged: (bool value) {
            setState(() {
              _rememberMe = value;
            });
          },
          onSubmit: _submit,
          onOpenSignUp: _goToSignUp,
          emailValidator: _validateEmail,
          passwordValidator: _validatePassword,
        ),
      ),
    );
  }
}
