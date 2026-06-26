import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/theme_provider.dart';

class GlassNavbar extends ConsumerWidget {
  const GlassNavbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartCount = ref.watch(cartItemCountProvider);
    final auth = ref.watch(authProvider);
    ref.watch(themeModeProvider);

    final bgColor = isDark ? Colors.black.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      constraints: const BoxConstraints(maxWidth: 960),
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // Logo
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: Text(
                    'DRONEHUB',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.5,
                      color: textColor,
                    ),
                  ),
                ),

                const Spacer(),

                // Nav links
                _NavLink('Flight Controllers', textColor, () => context.go('/products?category=flight_controller')),
                _NavLink('Motors & ESCs', textColor, () => context.go('/products?category=motor')),
                _NavLink('Cameras', textColor, () => context.go('/products?category=camera')),
                _NavLink('Support', textColor, () {}),

                const Spacer(),

                // Theme toggle
                _IconBtn(
                  icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: textColor,
                  onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                ),

                // Cart
                _CartBtn(count: cartCount, color: textColor, onTap: () {
                  if (GoRouterState.of(context).uri.path != '/cart') context.push('/cart');
                }),

                // Profile
                _IconBtn(
                  icon: auth.user != null ? Icons.person_rounded : Icons.person_outline_rounded,
                  color: auth.user != null ? AppColors.accent : textColor,
                  onTap: () => auth.user != null ? context.go('/profile') : context.go('/login'),
                ),

                // Admin
                if (auth.user?.role == 'admin') ...[
                  const SizedBox(width: 4),
                  _IconBtn(
                    icon: Icons.admin_panel_settings_outlined,
                    color: AppColors.accent,
                    onTap: () => context.go('/admin'),
                  ),
                ],

                const SizedBox(width: 8),

                // Shop CTA
                GestureDetector(
                  onTap: () => context.go('/products'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Shop',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NavLink(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.78)),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _CartBtn extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _CartBtn({required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 20, color: color),
            if (count > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
