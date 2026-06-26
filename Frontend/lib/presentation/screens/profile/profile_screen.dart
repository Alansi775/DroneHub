import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/app_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addr1Ctrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _postalCtrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _addr1Ctrl = TextEditingController(text: user?.addressLine1 ?? '');
    _cityCtrl = TextEditingController(text: user?.city ?? '');
    _countryCtrl = TextEditingController(text: user?.country ?? '');
    _postalCtrl = TextEditingController(text: user?.postalCode ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _addr1Ctrl, _cityCtrl, _countryCtrl, _postalCtrl]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user!;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => setState(() => _editing = true)),
          if (_editing)
            TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    child: user.avatar != null
                        ? ClipOval(child: CachedNetworkImage(imageUrl: user.avatar!, width: 96, height: 96, fit: BoxFit.cover))
                        : Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ),
                  if (user.isAdmin)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                        child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            ),

            const SizedBox(height: 12),
            Text(user.name, style: Theme.of(context).textTheme.titleLarge).animate().fadeIn(delay: 100.ms),
            Text(user.email, style: Theme.of(context).textTheme.bodyMedium).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: 28),

            if (!_editing) ...[
              _QuickActions(user: user),
              const SizedBox(height: 20),
              _SettingsSection(isDark: isDark, themeMode: themeMode, ref: ref),
            ] else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personal Info', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, size: 20))),
                    const SizedBox(height: 12),
                    TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined, size: 20))),
                    const SizedBox(height: 20),
                    Text('Shipping Address', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(controller: _addr1Ctrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined, size: 20))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'City'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: _postalCtrl, decoration: const InputDecoration(labelText: 'Postal'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _countryCtrl, decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.flag_outlined, size: 20))),
                    const SizedBox(height: 24),
                    AppButton(label: 'Save Changes', isLoading: _saving, onPressed: _save),
                  ],
                ),
              ),

            const SizedBox(height: 32),
            AppButton(
              label: 'Sign Out',
              isOutlined: true,
              icon: Icons.logout,
              color: AppColors.error,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/');
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.put('/users/profile', data: {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'addressLine1': _addr1Ctrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'postalCode': _postalCtrl.text.trim(),
      });
      final userData = (res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      final user = ref.read(authProvider).user!.copyWith(
        name: userData['name'],
        phone: userData['phone'],
        addressLine1: userData['address_line1'],
        city: userData['city'],
        country: userData['country'],
        postalCode: userData['postal_code'],
      );
      ref.read(authProvider.notifier).updateUser(user);
      setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QuickActions extends StatelessWidget {
  final user;
  const _QuickActions({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(icon: Icons.receipt_long_outlined, label: 'My Orders', onTap: () => context.push('/orders')),
        if (user.isAdmin)
          _ActionTile(icon: Icons.admin_panel_settings_outlined, label: 'Admin Panel', onTap: () => context.push('/admin'), color: AppColors.accent),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.darkTextSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final bool isDark;
  final ThemeMode themeMode;
  final WidgetRef ref;
  const _SettingsSection({required this.isDark, required this.themeMode, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 20),
              const SizedBox(width: 12),
              const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Switch(
            value: themeMode == ThemeMode.dark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
