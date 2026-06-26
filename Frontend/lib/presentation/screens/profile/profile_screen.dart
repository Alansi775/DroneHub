import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

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
    _initControllers(ref.read(authProvider).user);
  }

  void _initControllers(UserModel? u) {
    _nameCtrl    = TextEditingController(text: u?.name ?? '');
    _phoneCtrl   = TextEditingController(text: u?.phone ?? '');
    _addr1Ctrl   = TextEditingController(text: u?.addressLine1 ?? '');
    _cityCtrl    = TextEditingController(text: u?.city ?? '');
    _countryCtrl = TextEditingController(text: u?.country ?? '');
    _postalCtrl  = TextEditingController(text: u?.postalCode ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _addr1Ctrl, _cityCtrl, _countryCtrl, _postalCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
      final d = (res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      ref.read(authProvider.notifier).updateUser(
        ref.read(authProvider).user!.copyWith(
          name: d['name'],
          phone: d['phone'],
          addressLine1: d['address_line1'],
          city: d['city'],
          country: d['country'],
          postalCode: d['postal_code'],
        ),
      );
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

  void _cancelEdit() {
    _initControllers(ref.read(authProvider).user);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F8F8),
      body: isWide
          ? Row(
              children: [
                _LeftPanel(user: user, isDark: isDark, onEdit: () => setState(() => _editing = true)),
                Expanded(child: _RightPanel(
                  user: user, isDark: isDark, editing: _editing, saving: _saving,
                  formKey: _formKey,
                  nameCtrl: _nameCtrl, phoneCtrl: _phoneCtrl, addr1Ctrl: _addr1Ctrl,
                  cityCtrl: _cityCtrl, countryCtrl: _countryCtrl, postalCtrl: _postalCtrl,
                  onSave: _save, onCancel: _cancelEdit,
                  onStartEdit: () => setState(() => _editing = true),
                )),
              ],
            )
          : _MobileLayout(
              user: user, isDark: isDark, editing: _editing, saving: _saving,
              formKey: _formKey,
              nameCtrl: _nameCtrl, phoneCtrl: _phoneCtrl, addr1Ctrl: _addr1Ctrl,
              cityCtrl: _cityCtrl, countryCtrl: _countryCtrl, postalCtrl: _postalCtrl,
              onSave: _save, onCancel: _cancelEdit,
              onStartEdit: () => setState(() => _editing = true),
            ),
    );
  }
}

// ─── Initials helper ──────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
}

// ─── Avatar widget ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final UserModel user;
  final double radius;
  const _Avatar({required this.user, this.radius = 44});

  @override
  Widget build(BuildContext context) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
        child: ClipOval(
          child: Image.network(
            user.avatar!,
            width: radius * 2, height: radius * 2, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _InitialsCircle(name: user.name, radius: radius),
          ),
        ),
      );
    }
    return _InitialsCircle(name: user.name, radius: radius);
  }
}

class _InitialsCircle extends StatelessWidget {
  final String name;
  final double radius;
  const _InitialsCircle({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
      child: Text(
        _initials(name),
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─── LEFT PANEL (desktop only) ────────────────────────────────────────────────

class _LeftPanel extends ConsumerWidget {
  final UserModel user;
  final bool isDark;
  final VoidCallback onEdit;
  const _LeftPanel({required this.user, required this.isDark, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final bg = isDark ? const Color(0xFF080808) : Colors.white;
    final border = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8);

    return Container(
      width: 300,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 32),

          // Avatar
          _Avatar(user: user, radius: 52)
              .animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 16),

          // Name
          Text(
            user.name,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 4),

          // Email
          Text(
            user.email,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 12),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: (user.isAdmin ? AppColors.accent : AppColors.success).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (user.isAdmin ? AppColors.accent : AppColors.success).withValues(alpha: 0.25)),
            ),
            child: Text(
              user.isAdmin ? 'Administrator' : 'Customer',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: user.isAdmin ? AppColors.accent : AppColors.success, letterSpacing: 0.5),
            ),
          ).animate().fadeIn(delay: 160.ms),

          const SizedBox(height: 32),
          Divider(color: border),
          const SizedBox(height: 12),

          // Navigation
          _NavItem(icon: Icons.person_outline_rounded, label: 'Edit Profile', isDark: isDark, onTap: onEdit),
          _NavItem(icon: Icons.receipt_long_outlined, label: 'My Orders', isDark: isDark, onTap: () => context.push('/orders')),
          if (user.isAdmin)
            _NavItem(icon: Icons.admin_panel_settings_outlined, label: 'Admin Panel', isDark: isDark,
                color: AppColors.accent, onTap: () => context.push('/admin')),

          const Spacer(),
          Divider(color: border),

          // Dark mode toggle
          _DarkModeRow(isDark: isDark, themeMode: themeMode, ref: ref),

          const SizedBox(height: 8),

          // Sign out
          _SignOutBtn(isDark: isDark, onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/');
          }),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final Color? color;
  const _NavItem({required this.icon, required this.label, required this.isDark, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? Colors.white70 : Colors.black54);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.transparent,
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: c.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}

class _DarkModeRow extends StatelessWidget {
  final bool isDark;
  final ThemeMode themeMode;
  final WidgetRef ref;
  const _DarkModeRow({required this.isDark, required this.themeMode, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(children: [
        Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 12),
        Text('Dark Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
        const Spacer(),
        Switch(
          value: themeMode == ThemeMode.dark,
          onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          activeColor: AppColors.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

class _SignOutBtn extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _SignOutBtn({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.error.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: const Row(children: [
          Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
          SizedBox(width: 12),
          Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
        ]),
      ),
    );
  }
}

// ─── RIGHT PANEL (desktop) ────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final UserModel user;
  final bool isDark, editing, saving;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, phoneCtrl, addr1Ctrl, cityCtrl, countryCtrl, postalCtrl;
  final VoidCallback onSave, onCancel, onStartEdit;

  const _RightPanel({
    required this.user, required this.isDark, required this.editing, required this.saving,
    required this.formKey, required this.nameCtrl, required this.phoneCtrl,
    required this.addr1Ctrl, required this.cityCtrl, required this.countryCtrl,
    required this.postalCtrl, required this.onSave, required this.onCancel, required this.onStartEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(40, MediaQuery.of(context).padding.top + 40, 40, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    editing ? 'Edit Profile' : 'Account Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    editing ? 'Update your personal information' : 'Your account information',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ]),
              ),
              if (!editing)
                GestureDetector(
                  onTap: onStartEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF222) : const Color(0xFFDDD)),
                    ),
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 6),
                      Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                    ]),
                  ),
                ),
            ]),

            const SizedBox(height: 32),

            if (!editing) ...[
              _InfoCard(user: user, isDark: isDark),
            ] else ...[
              _EditForm(
                isDark: isDark, saving: saving, formKey: formKey,
                nameCtrl: nameCtrl, phoneCtrl: phoneCtrl, addr1Ctrl: addr1Ctrl,
                cityCtrl: cityCtrl, countryCtrl: countryCtrl, postalCtrl: postalCtrl,
                onSave: onSave, onCancel: onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Info card (view mode) ────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final UserModel user;
  final bool isDark;
  const _InfoCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final border = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal info
        _SectionLabel('Personal Information', isDark),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardBg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Column(children: [
            _InfoRow(icon: Icons.person_outline_rounded, label: 'Name', value: user.name, isDark: isDark),
            Divider(height: 1, color: border),
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email, isDark: isDark),
            if (user.phone != null && user.phone!.isNotEmpty) ...[
              Divider(height: 1, color: border),
              _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phone!, isDark: isDark),
            ],
          ]),
        ),

        if (user.addressLine1 != null && user.addressLine1!.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel('Shipping Address', isDark),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: Column(children: [
              _InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: user.addressLine1!, isDark: isDark),
              if (user.city != null && user.city!.isNotEmpty) ...[
                Divider(height: 1, color: border),
                _InfoRow(icon: Icons.location_city_outlined, label: 'City', value: '${user.city}${user.postalCode != null ? "  ${user.postalCode}" : ""}', isDark: isDark),
              ],
              if (user.country != null && user.country!.isNotEmpty) ...[
                Divider(height: 1, color: border),
                _InfoRow(icon: Icons.flag_outlined, label: 'Country', value: user.country!, isDark: isDark),
              ],
            ]),
          ),
        ] else ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE), style: BorderStyle.solid),
            ),
            child: Row(children: [
              Icon(Icons.location_on_outlined, size: 20, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(width: 12),
              Text('No shipping address added', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
            ]),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 17, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500)),
        const SizedBox(width: 16),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black), textAlign: TextAlign.end)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel(this.label, this.isDark);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8,
        color: isDark ? Colors.white38 : Colors.black38),
  );
}

// ─── Edit form ────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final bool isDark, saving;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, phoneCtrl, addr1Ctrl, cityCtrl, countryCtrl, postalCtrl;
  final VoidCallback onSave, onCancel;

  const _EditForm({
    required this.isDark, required this.saving, required this.formKey,
    required this.nameCtrl, required this.phoneCtrl, required this.addr1Ctrl,
    required this.cityCtrl, required this.countryCtrl, required this.postalCtrl,
    required this.onSave, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Personal Information', isDark),
          const SizedBox(height: 12),

          _FormField(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outline_rounded, isDark: isDark,
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
          const SizedBox(height: 10),
          _FormField(ctrl: phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, isDark: isDark,
              keyboard: TextInputType.phone),

          const SizedBox(height: 28),
          _SectionLabel('Shipping Address', isDark),
          const SizedBox(height: 12),

          _FormField(ctrl: addr1Ctrl, label: 'Street Address', icon: Icons.location_on_outlined, isDark: isDark),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(child: _FormField(ctrl: cityCtrl, label: 'City', icon: Icons.location_city_outlined, isDark: isDark)),
            const SizedBox(width: 12),
            SizedBox(width: 140, child: _FormField(ctrl: postalCtrl, label: 'Postal Code', isDark: isDark, keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          _FormField(ctrl: countryCtrl, label: 'Country', icon: Icons.flag_outlined, isDark: isDark),

          const SizedBox(height: 28),

          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: saving ? null : onSave,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: saving ? AppColors.accent.withValues(alpha: 0.6) : AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onCancel,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF333) : const Color(0xFFDDD)),
                ),
                child: Center(child: Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45))),
              ),
            ),
          ]),
        ],
      ).animate().fadeIn(duration: 250.ms),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData? icon;
  final bool isDark;
  final TextInputType keyboard;
  final String? Function(String?)? validator;

  const _FormField({required this.ctrl, required this.label, required this.isDark, this.icon, this.keyboard = TextInputType.text, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
        prefixIcon: icon != null ? Icon(icon, size: 17, color: isDark ? Colors.white38 : Colors.black38) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF111) : const Color(0xFFF5F5F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.error)),
      ),
    );
  }
}

// ─── Mobile layout ────────────────────────────────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  final UserModel user;
  final bool isDark, editing, saving;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, phoneCtrl, addr1Ctrl, cityCtrl, countryCtrl, postalCtrl;
  final VoidCallback onSave, onCancel, onStartEdit;

  const _MobileLayout({
    required this.user, required this.isDark, required this.editing, required this.saving,
    required this.formKey, required this.nameCtrl, required this.phoneCtrl,
    required this.addr1Ctrl, required this.cityCtrl, required this.countryCtrl,
    required this.postalCtrl, required this.onSave, required this.onCancel, required this.onStartEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final bg = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final border = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            color: isDark ? Colors.black : const Color(0xFFF8F8F8),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
            child: Column(children: [
              _Avatar(user: user, radius: 44).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              Text(user.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 4),
              Text(user.email, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (user.isAdmin ? AppColors.accent : AppColors.success).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isAdmin ? 'Administrator' : 'Customer',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: user.isAdmin ? AppColors.accent : AppColors.success),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!editing) ...[
                  _InfoCard(user: user, isDark: isDark),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onStartEdit,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF111) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.edit_outlined, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 8),
                        Text('Edit Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
                      ]),
                    ),
                  ),
                ] else ...[
                  _EditForm(
                    isDark: isDark, saving: saving, formKey: formKey,
                    nameCtrl: nameCtrl, phoneCtrl: phoneCtrl, addr1Ctrl: addr1Ctrl,
                    cityCtrl: cityCtrl, countryCtrl: countryCtrl, postalCtrl: postalCtrl,
                    onSave: onSave, onCancel: onCancel,
                  ),
                ],

                const SizedBox(height: 24),

                // Nav items
                Container(
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                  child: Column(children: [
                    _MobileNavItem(icon: Icons.receipt_long_outlined, label: 'My Orders', isDark: isDark, onTap: () => context.push('/orders')),
                    if (user.isAdmin) ...[
                      Divider(height: 1, color: border),
                      _MobileNavItem(icon: Icons.admin_panel_settings_outlined, label: 'Admin Panel', isDark: isDark, color: AppColors.accent, onTap: () => context.push('/admin')),
                    ],
                  ]),
                ),

                const SizedBox(height: 16),

                // Dark mode
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                  child: _DarkModeRow(isDark: isDark, themeMode: themeMode, ref: ref),
                ),

                const SizedBox(height: 16),
                _SignOutBtn(isDark: isDark, onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/');
                }),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final Color? color;
  const _MobileNavItem({required this.icon, required this.label, required this.isDark, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? Colors.white70 : Colors.black54);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c))),
          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: c.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}
