// lib/presentation/screens/main_shell.dart
import 'package:flutter/material.dart';
import '../widgets/common/glass_navbar.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page content (full screen)
          Positioned.fill(child: child),

          // Floating glass navbar — top center
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(child: const GlassNavbar()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
