import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:unihub/screens/ui/noise_overlay.dart';

class ForgotPasswordScreenView extends StatefulWidget {
  const ForgotPasswordScreenView({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.isSubmitting,
    required this.hasSentEmail,
    required this.onSubmit,
    required this.emailValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSubmitting;
  final bool hasSentEmail;
  final Future<void> Function() onSubmit;
  final String? Function(String?) emailValidator;

  @override
  State<ForgotPasswordScreenView> createState() =>
      _ForgotPasswordScreenViewState();
}

class _ForgotPasswordScreenViewState extends State<ForgotPasswordScreenView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _buttonHoverController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;

  bool _emailFocused = false;
  bool _buttonHovered = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _buttonHoverController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.16), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _buttonScaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _buttonHoverController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonHoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Stack(
      children: <Widget>[
        const GrainBackground(),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: Navigator.of(context).pop,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colors.primary,
                size: 24,
              ),
              tooltip: 'Inapoi',
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              colors.surface.withValues(alpha: 0.9),
                              colors.surface.withValues(alpha: 0.72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.18),
                            width: 1.5,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Form(
                          key: widget.formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Container(
                                height: 64,
                                width: 64,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      colors.primary,
                                      colors.secondary.withValues(alpha: 0.9),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Resetare parola',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Introdu adresa de email asociata contului tau. Iti vom trimite instructiunile pentru resetarea parolei.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                              ),
                              if (widget.hasSentEmail) ...<Widget>[
                                const SizedBox(height: 18),
                                _SuccessMessage(colors: colors),
                              ],
                              const SizedBox(height: 22),
                              _EmailField(
                                controller: widget.emailController,
                                validator: widget.emailValidator,
                                colors: colors,
                                isFocused: _emailFocused,
                                onFocusChange: (bool focused) {
                                  setState(() => _emailFocused = focused);
                                },
                              ),
                              const SizedBox(height: 20),
                              _SubmitButton(
                                isLoading: widget.isSubmitting,
                                onPressed: widget.isSubmitting
                                    ? null
                                    : widget.onSubmit,
                                colors: colors,
                                isHovered: _buttonHovered,
                                buttonScaleAnimation: _buttonScaleAnimation,
                                onHoverChange: (bool hovered) {
                                  setState(() => _buttonHovered = hovered);
                                  if (hovered) {
                                    _buttonHoverController.forward();
                                  } else {
                                    _buttonHoverController.reverse();
                                  }
                                },
                                label: widget.hasSentEmail
                                    ? 'Retrimite emailul'
                                    : 'Trimite emailul',
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: Navigator.of(context).pop,
                                child: const Text('Inapoi la autentificare'),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.mark_email_read_outlined, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Daca exista un cont pentru acest email, vei primi in scurt timp un link de resetare.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    required this.validator,
    required this.colors,
    required this.isFocused,
    required this.onFocusChange,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final ColorScheme colors;
  final bool isFocused;
  final ValueChanged<bool> onFocusChange;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: onFocusChange,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isFocused
              ? <BoxShadow>[
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.28),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          validator: validator,
          style: TextStyle(color: colors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'nume@exemplu.com',
            prefixIcon: Icon(
              Icons.alternate_email_rounded,
              size: 20,
              color: isFocused ? colors.primary : colors.onSurfaceVariant,
            ),
            filled: true,
            fillColor: colors.surface.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colors.outline.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colors.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isLoading,
    required this.onPressed,
    required this.colors,
    required this.isHovered,
    required this.buttonScaleAnimation,
    required this.onHoverChange,
    required this.label,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final ColorScheme colors;
  final bool isHovered;
  final Animation<double> buttonScaleAnimation;
  final ValueChanged<bool> onHoverChange;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChange(true),
      onExit: (_) => onHoverChange(false),
      child: ScaleTransition(
        scale: buttonScaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                colors.primary,
                colors.secondary.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.primary.withValues(alpha: isHovered ? 0.4 : 0.24),
                blurRadius: isHovered ? 18 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
