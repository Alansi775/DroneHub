import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirect;
  const LoginScreen({super.key, this.redirect});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) context.go(widget.redirect?.isNotEmpty == true ? widget.redirect! : '/');
  }

  Future<void> _google() async {
    final ok = await ref.read(authProvider.notifier).googleSignIn();
    if (ok && mounted) context.go(widget.redirect?.isNotEmpty == true ? widget.redirect! : '/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Row(
        children: [
          if (size.width > 900)
            Expanded(child: _LeftVisualPanel(isDark: isDark)),

          Container(
            width: size.width > 900 ? 500 : size.width,
            color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo — text only, no icon
                      GestureDetector(
                        onTap: () => context.go('/'),
                        child: Text(
                          'DRONEHUB',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 64),

                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05, curve: Curves.easeOut),

                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: () => context.pushReplacement('/register'),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
                            children: [
                              const TextSpan(text: 'New to DroneHub? '),
                              TextSpan(
                                text: 'Create an account',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0070D5),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 40),

                      _GoogleBtn(isLoading: auth.isLoading, onTap: _google, isDark: isDark)
                          .animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or continue with email',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _Field(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        hint: 'name@example.com',
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 20),

                      _Field(
                        controller: _passCtrl,
                        label: 'Password',
                        hint: 'Enter your password',
                        isDark: isDark,
                        obscure: _obscure,
                        onToggleObscure: () => setState(() => _obscure = !_obscure),
                        validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                        onSubmit: (_) => _submit(),
                      ).animate().fadeIn(delay: 250.ms),

                      if (auth.error != null) ...[
                        const SizedBox(height: 16),
                        Text(auth.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ],

                      const SizedBox(height: 32),

                      _SignInBtn(isLoading: auth.isLoading, onTap: _submit, isDark: isDark)
                          .animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 48),

                      Text(
                        'By continuing, you agree to DroneHub\'s Terms of Service and Privacy Policy.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white24 : Colors.black26, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Left visual panel ────────────────────────────────────────────────────────

class _LeftVisualPanel extends StatelessWidget {
  final bool isDark;
  const _LeftVisualPanel({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: isDark
              ? [const Color(0xFF12131C), const Color(0xFF000000)]
              : [const Color(0xFFF4F7FA), const Color(0xFFFFFFFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: isDark ? 0.05 : 0.06),
              ),
            ),
          ),

          Positioned(
            bottom: 80,
            left: 64,
            right: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Future of\nFlight Management.',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.2,
                    letterSpacing: -1,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, curve: Curves.easeOut),
                const SizedBox(height: 16),
                Text(
                  'Industrial-grade components built\nfor professional drone pilots.',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.6,
                    fontWeight: FontWeight.w300,
                  ),
                ).animate().fadeIn(delay: 320.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field ────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final bool isDark;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmit;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.isDark,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          onFieldSubmitted: onSubmit,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 13),
            suffixIcon: onToggleObscure != null
                ? GestureDetector(
                    onTap: onToggleObscure,
                    child: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3)),
            ),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.error)),
          ),
        ),
      ],
    );
  }
}

// ─── Google button ────────────────────────────────────────────────────────────

class _GoogleBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final bool isDark;
  const _GoogleBtn({required this.isLoading, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GooglePainter())),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    const pi = 3.14159265;

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.72),
        start, sweep, false,
        Paint()
          ..color = color
          ..strokeWidth = size.width * 0.22
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(-pi / 6, pi * 2 / 3, const Color(0xFF4285F4));
    arc(-pi / 6 + pi * 2 / 3, pi * 2 / 3, const Color(0xFF34A853));
    arc(-pi / 6 + pi * 4 / 3, pi * 2 / 3, const Color(0xFFEA4335));

    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width * 0.95, center.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.22
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Sign in button ───────────────────────────────────────────────────────────

class _SignInBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final bool isDark;
  const _SignInBtn({required this.isLoading, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isLoading
              ? (isDark ? Colors.white70 : Colors.black54)
              : (isDark ? Colors.white : Colors.black),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: isDark ? Colors.black : Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Sign In',
                  style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
        ),
      ),
    );
  }
}
