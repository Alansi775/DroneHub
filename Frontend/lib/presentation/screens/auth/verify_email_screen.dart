import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api_service.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String token;
  const VerifyEmailScreen({super.key, required this.token});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = true;
  bool _success = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/auth/verify-email/${widget.token}');
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _loading = false;
        _success = data['success'] == true;
        _message = data['message'] ?? 'Email verified!';
      });
    } catch (e) {
      String msg = 'Verification failed. The link may be invalid or expired.';
      if (e.toString().contains('message')) {
        try {
          final m = (e as dynamic).response?.data?['message'];
          if (m != null) msg = m.toString();
        } catch (_) {}
      }
      setState(() { _loading = false; _success = false; _message = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F8F8),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _loading ? _buildLoading(isDark) : _buildResult(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3)),
        const SizedBox(height: 24),
        Text('Verifying your email…', style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54)),
      ],
    ).animate().fadeIn();
  }

  Widget _buildResult(bool isDark) {
    final card = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final border = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8);

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
              children: const [TextSpan(text: 'Drone'), TextSpan(text: 'Hub', style: TextStyle(color: AppColors.accent))],
            ),
          ),
          const SizedBox(height: 32),

          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_success ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
            ),
            child: Icon(_success ? Icons.check_rounded : Icons.error_outline_rounded,
                size: 36, color: _success ? AppColors.success : AppColors.error),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: 20),

          Text(
            _success ? 'Email Verified!' : 'Verification Failed',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 10),

          Text(
            _message,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45, height: 1.5),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),

          GestureDetector(
            onTap: () => context.go(_success ? '/login' : '/register'),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: _success ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: _success ? null : Border.all(color: border),
              ),
              child: Center(
                child: Text(
                  _success ? 'Sign In Now' : 'Register Again',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _success ? Colors.white : (isDark ? Colors.white60 : Colors.black45),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 250.ms),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.04);
  }
}