import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/screens/ui/forgot_password_screen_view.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isSubmitting = false;
  bool _hasSentEmail = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      return 'Email valid obligatoriu';
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

    bool success = true;
    try {
      await _supabase.auth.resetPasswordForEmail(_emailController.text.trim());
    } catch (_) {
      success = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _hasSentEmail = success;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nu am putut trimite emailul de resetare. Verifica datele si conexiunea.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ForgotPasswordScreenView(
          formKey: _formKey,
          emailController: _emailController,
          isSubmitting: _isSubmitting,
          hasSentEmail: _hasSentEmail,
          onSubmit: _submit,
          emailValidator: _validateEmail,
        ),
      ),
    );
  }
}
