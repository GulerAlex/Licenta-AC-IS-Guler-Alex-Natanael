import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:unihub/screens/ui/noise_overlay.dart';
import 'dart:ui' as ui;

class SignUpScreenView extends StatefulWidget {
  const SignUpScreenView({
    super.key,
    required this.formKey,
    required this.numeController,
    required this.prenumeController,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.emailValidator,
    required this.numeValidator,
    required this.prenumeValidator,
    required this.passwordValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController numeController;
  final TextEditingController prenumeController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;
  final String? Function(String?) emailValidator;
  final String? Function(String?) numeValidator;
  final String? Function(String?) prenumeValidator;
  final String? Function(String?) passwordValidator;

  @override
  State<SignUpScreenView> createState() => _SignUpScreenViewState();
}

class _SignUpScreenViewState extends State<SignUpScreenView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingController;
  late AnimationController _fieldStaggerController;
  late AnimationController _buttonHoverController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _field1Animation;
  late Animation<double> _field2Animation;
  late Animation<double> _field3Animation;
  late Animation<double> _field4Animation;
  late Animation<double> _buttonScaleAnimation;

  bool _nomeFocused = false;
  bool _prenumeFocused = false;
  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool _buttonHovered = false;

  @override
  void initState() {
    super.initState();

    // Main entrance animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Floating animation for header
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    // Staggered field animations
    _fieldStaggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _field1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fieldStaggerController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _field2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fieldStaggerController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _field3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fieldStaggerController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _field4Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fieldStaggerController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Button hover animation
    _buttonHoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _buttonHoverController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _fieldStaggerController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    _fieldStaggerController.dispose();
    _buttonHoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        const GrainBackground(),
        // Back button
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.15),
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
        // Main content
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: _floatingAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -_floatingAnimation.value),
                            child: Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colors.primary,
                                    colors.secondary.withOpacity(0.9),
                                    colors.tertiary.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withOpacity(0.5),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: colors.secondary.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(-5, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_add_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      // Title with Gradient Underline
                      Column(
                        children: [
                          Text(
                            'Creeaza Cont',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                  letterSpacing: -0.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          // Gradient Underline
                          Container(
                            height: 4,
                            width: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  colors.primary.withOpacity(0.3),
                                  colors.secondary,
                                  colors.tertiary.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Alaturate-te la UniHub',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                              fontSize: 20,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Creeaza un cont folosind email si parola',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Form Card with Glass Morphism
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surface.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.primary.withOpacity(0.25),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withOpacity(0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: colors.secondary.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(8, 8),
                                ),
                                BoxShadow(
                                  color: colors.tertiary.withOpacity(0.06),
                                  blurRadius: 15,
                                  offset: const Offset(-6, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: widget.formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    // Nome Field with Stagger Animation
                                    FadeTransition(
                                      opacity: _field1Animation,
                                      child: _buildModernTextField(
                                        context: context,
                                        controller: widget.numeController,
                                        label: 'Nume',
                                        hint: '',
                                        icon: Icons.badge_outlined,
                                        validator: widget.numeValidator,
                                        colors: colors,
                                        onFocusChange: (focused) {
                                          setState(
                                            () => _nomeFocused = focused,
                                          );
                                        },
                                        isFocused: _nomeFocused,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Prenume Field with Stagger Animation
                                    FadeTransition(
                                      opacity: _field2Animation,
                                      child: _buildModernTextField(
                                        context: context,
                                        controller: widget.prenumeController,
                                        label: 'Prenume',
                                        hint: '',
                                        icon: Icons.person_outline_rounded,
                                        validator: widget.prenumeValidator,
                                        colors: colors,
                                        onFocusChange: (focused) {
                                          setState(
                                            () => _prenumeFocused = focused,
                                          );
                                        },
                                        isFocused: _prenumeFocused,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Email Field with Stagger Animation
                                    FadeTransition(
                                      opacity: _field3Animation,
                                      child: _buildModernTextField(
                                        context: context,
                                        controller: widget.emailController,
                                        label: 'Email',
                                        hint: 'nume@exemplu.com',
                                        icon: Icons.alternate_email_rounded,
                                        validator: widget.emailValidator,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        colors: colors,
                                        onFocusChange: (focused) {
                                          setState(
                                            () => _emailFocused = focused,
                                          );
                                        },
                                        isFocused: _emailFocused,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Password Field with Stagger Animation
                                    FadeTransition(
                                      opacity: _field4Animation,
                                      child: _buildModernTextField(
                                        context: context,
                                        controller: widget.passwordController,
                                        label: 'Parola',
                                        hint: '',
                                        icon: Icons.lock_outline_rounded,
                                        validator: widget.passwordValidator,
                                        obscureText: widget.obscurePassword,
                                        isPasswordField: true,
                                        onVisibilityToggle:
                                            widget.onTogglePassword,
                                        colors: colors,
                                        onFocusChange: (focused) {
                                          setState(
                                            () => _passwordFocused = focused,
                                          );
                                        },
                                        isFocused: _passwordFocused,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Sign Up Button with Hover Effects
                                    _buildModernButton(
                                      context: context,
                                      isLoading: widget.isSubmitting,
                                      onPressed: widget.isSubmitting
                                          ? null
                                          : widget.onSubmit,
                                      colors: colors,
                                      onHoverChange: (hovered) {
                                        setState(
                                          () => _buttonHovered = hovered,
                                        );
                                        if (hovered) {
                                          _buttonHoverController.forward();
                                        } else {
                                          _buttonHoverController.reverse();
                                        }
                                      },
                                      isHovered: _buttonHovered,
                                      buttonScaleAnimation:
                                          _buttonScaleAnimation,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom Accent Bar
                      const SizedBox(height: 20),
                      Container(
                        height: 3,
                        width: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              colors.primary.withOpacity(0.2),
                              colors.secondary,
                              colors.tertiary.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    required ColorScheme colors,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool isPasswordField = false,
    VoidCallback? onVisibilityToggle,
    ValueChanged<bool>? onFocusChange,
    bool isFocused = false,
  }) {
    return Focus(
      onFocusChange: onFocusChange,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: colors.secondary.withOpacity(0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText && widget.obscurePassword,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(
              icon,
              size: 20,
              color: isFocused
                  ? colors.primary
                  : colors.primary.withOpacity(0.7),
            ),
            suffixIcon: isPasswordField
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onVisibilityToggle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          widget.obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: isFocused
                              ? colors.secondary
                              : colors.secondary.withOpacity(0.7),
                        ),
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: isFocused
                ? colors.primary.withOpacity(0.12)
                : colors.primary.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colors.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colors.secondary.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primary, width: 2.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colors.error.withOpacity(0.5),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            labelStyle: TextStyle(
              color: isFocused ? colors.primary : colors.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: validator,
          style: TextStyle(color: colors.onSurface, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required BuildContext context,
    required bool isLoading,
    required VoidCallback? onPressed,
    required ColorScheme colors,
    required ValueChanged<bool>? onHoverChange,
    required bool isHovered,
    required Animation<double> buttonScaleAnimation,
  }) {
    return MouseRegion(
      onEnter: (_) => onHoverChange?.call(true),
      onExit: (_) => onHoverChange?.call(false),
      child: ScaleTransition(
        scale: buttonScaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary,
                colors.secondary.withOpacity(0.85),
                colors.primary.withOpacity(0.9),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(isHovered ? 0.6 : 0.5),
                blurRadius: isHovered ? 24 : 18,
                offset: const Offset(0, 6),
                spreadRadius: isHovered ? 3 : 2,
              ),
              BoxShadow(
                color: colors.secondary.withOpacity(isHovered ? 0.3 : 0.2),
                blurRadius: isHovered ? 14 : 10,
                offset: const Offset(-4, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ),
                            Container(
                              height: 8,
                              width: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      AnimatedScale(
                        scale: isHovered ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    if (!isLoading) const SizedBox(width: 8),
                    Text(
                      isLoading ? 'Se creeaza contul...' : 'Creeaza cont',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
