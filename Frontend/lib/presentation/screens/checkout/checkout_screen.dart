import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/order_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _placing = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addr1Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _postalCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl    = TextEditingController(text: user?.name ?? '');
    _emailCtrl   = TextEditingController(text: user?.email ?? '');
    _phoneCtrl   = TextEditingController(text: user?.phone ?? '');
    _addr1Ctrl   = TextEditingController(text: user?.addressLine1 ?? '');
    _cityCtrl    = TextEditingController(text: user?.city ?? '');
    _countryCtrl = TextEditingController(text: user?.country ?? '');
    _postalCtrl  = TextEditingController(text: user?.postalCode ?? '');
    _notesCtrl   = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _addr1Ctrl, _cityCtrl, _countryCtrl, _postalCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _placeOrder(double total) async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(total: total, email: _emailCtrl.text.trim()),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _placing = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final address = ShippingAddress(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        addressLine1: _addr1Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim().isEmpty ? null : _postalCtrl.text.trim(),
      );
      final order = await repo.createOrder(
        address,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) context.go('/order-success/${order.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _openMapPicker() async {
    final result = await showDialog<_PickedAddress>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MapPickerDialog(
        initialAddress: _addr1Ctrl.text,
        initialCity: _cityCtrl.text,
        initialCountry: _countryCtrl.text,
      ),
    );
    if (result != null && mounted) {
      _addr1Ctrl.text    = result.address;
      _cityCtrl.text     = result.city;
      _countryCtrl.text  = result.country;
      _postalCtrl.text   = result.postal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartAsync = ref.watch(cartProvider);
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(isDark: isDark),
            Expanded(
              child: cartAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('$e')),
                data: (cart) {
                  final total = cart.subtotal;
                  return Form(
                    key: _formKey,
                    child: w > 900
                        ? _DesktopLayout(
                            isDark: isDark, cart: cart, total: total,
                            nameCtrl: _nameCtrl, emailCtrl: _emailCtrl, phoneCtrl: _phoneCtrl,
                            addr1Ctrl: _addr1Ctrl, cityCtrl: _cityCtrl, countryCtrl: _countryCtrl,
                            postalCtrl: _postalCtrl, notesCtrl: _notesCtrl,
                            placing: _placing, onMapPicker: _openMapPicker,
                            onPlaceOrder: () => _placeOrder(total),
                          )
                        : _MobileLayout(
                            isDark: isDark, cart: cart, total: total,
                            nameCtrl: _nameCtrl, emailCtrl: _emailCtrl, phoneCtrl: _phoneCtrl,
                            addr1Ctrl: _addr1Ctrl, cityCtrl: _cityCtrl, countryCtrl: _countryCtrl,
                            postalCtrl: _postalCtrl, notesCtrl: _notesCtrl,
                            placing: _placing, onMapPicker: _openMapPicker,
                            onPlaceOrder: () => _placeOrder(total),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isDark;
  const _TopBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: fg),
          ),
          const SizedBox(width: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: fg),
              children: const [TextSpan(text: 'Drone'), TextSpan(text: 'Hub', style: TextStyle(color: AppColors.accent))],
            ),
          ),
          const Spacer(),
          Text('Cart', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
          Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? Colors.white24 : Colors.black26),
          Text('Checkout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

// ─── Desktop Layout ───────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final bool isDark;
  final dynamic cart;
  final double total;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl, addr1Ctrl, cityCtrl, countryCtrl, postalCtrl, notesCtrl;
  final bool placing;
  final VoidCallback onMapPicker, onPlaceOrder;

  const _DesktopLayout({
    required this.isDark, required this.cart, required this.total,
    required this.nameCtrl, required this.emailCtrl, required this.phoneCtrl,
    required this.addr1Ctrl, required this.cityCtrl, required this.countryCtrl,
    required this.postalCtrl, required this.notesCtrl,
    required this.placing, required this.onMapPicker, required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 36, 32, 48),
            child: _DeliveryPanel(
              isDark: isDark,
              nameCtrl: nameCtrl, emailCtrl: emailCtrl, phoneCtrl: phoneCtrl,
              addr1Ctrl: addr1Ctrl, cityCtrl: cityCtrl, countryCtrl: countryCtrl,
              postalCtrl: postalCtrl, notesCtrl: notesCtrl,
              onMapPicker: onMapPicker,
            ),
          ),
        ),
        Container(width: 1, color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE)),
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 36, 40, 48),
            child: _SummaryPanel(
              isDark: isDark, cart: cart, total: total,
              placing: placing, onPlaceOrder: onPlaceOrder,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Mobile Layout ────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final bool isDark;
  final dynamic cart;
  final double total;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl, addr1Ctrl, cityCtrl, countryCtrl, postalCtrl, notesCtrl;
  final bool placing;
  final VoidCallback onMapPicker, onPlaceOrder;

  const _MobileLayout({
    required this.isDark, required this.cart, required this.total,
    required this.nameCtrl, required this.emailCtrl, required this.phoneCtrl,
    required this.addr1Ctrl, required this.cityCtrl, required this.countryCtrl,
    required this.postalCtrl, required this.notesCtrl,
    required this.placing, required this.onMapPicker, required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      child: Column(
        children: [
          _DeliveryPanel(
            isDark: isDark,
            nameCtrl: nameCtrl, emailCtrl: emailCtrl, phoneCtrl: phoneCtrl,
            addr1Ctrl: addr1Ctrl, cityCtrl: cityCtrl, countryCtrl: countryCtrl,
            postalCtrl: postalCtrl, notesCtrl: notesCtrl,
            onMapPicker: onMapPicker,
          ),
          const SizedBox(height: 32),
          _SummaryPanel(isDark: isDark, cart: cart, total: total, placing: placing, onPlaceOrder: onPlaceOrder),
        ],
      ),
    );
  }
}

// ─── Delivery Panel ───────────────────────────────────────────────────────────

class _DeliveryPanel extends StatelessWidget {
  final bool isDark;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl, addr1Ctrl, cityCtrl, countryCtrl, postalCtrl, notesCtrl;
  final VoidCallback onMapPicker;

  const _DeliveryPanel({
    required this.isDark,
    required this.nameCtrl, required this.emailCtrl, required this.phoneCtrl,
    required this.addr1Ctrl, required this.cityCtrl, required this.countryCtrl,
    required this.postalCtrl, required this.notesCtrl,
    required this.onMapPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('CONTACT INFORMATION', isDark: isDark).animate().fadeIn(),
        const SizedBox(height: 16),
        _Field(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outline_rounded, isDark: isDark, required: true),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Field(ctrl: emailCtrl, label: 'Email Address', icon: Icons.email_outlined, isDark: isDark, required: true, type: TextInputType.emailAddress)),
          const SizedBox(width: 14),
          Expanded(child: _Field(ctrl: phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, isDark: isDark, type: TextInputType.phone)),
        ]),

        const SizedBox(height: 36),
        Row(
          children: [
            _SectionLabel('DELIVERY ADDRESS', isDark: isDark).animate().fadeIn(delay: 80.ms),
            const Spacer(),
            GestureDetector(
              onTap: onMapPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 14, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text('Pick on Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Field(ctrl: addr1Ctrl, label: 'Street Address', icon: Icons.location_on_outlined, isDark: isDark, required: true),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Field(ctrl: cityCtrl, label: 'City', icon: Icons.location_city_outlined, isDark: isDark, required: true)),
          const SizedBox(width: 14),
          Expanded(child: _Field(ctrl: countryCtrl, label: 'Country', icon: Icons.flag_outlined, isDark: isDark, required: true)),
        ]),
        const SizedBox(height: 14),
        _Field(ctrl: postalCtrl, label: 'Postal Code (optional)', icon: Icons.markunread_mailbox_outlined, isDark: isDark),

        const SizedBox(height: 36),
        _SectionLabel('ORDER NOTES', isDark: isDark).animate().fadeIn(delay: 120.ms),
        const SizedBox(height: 16),
        _Field(ctrl: notesCtrl, label: 'Special instructions (optional)', icon: Icons.notes_outlined, isDark: isDark, maxLines: 3),
      ],
    );
  }
}

// ─── Summary Panel ────────────────────────────────────────────────────────────

class _SummaryPanel extends StatelessWidget {
  final bool isDark;
  final dynamic cart;
  final double total;
  final bool placing;
  final VoidCallback onPlaceOrder;

  const _SummaryPanel({
    required this.isDark, required this.cart, required this.total,
    required this.placing, required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final border = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8);
    final fg     = isDark ? Colors.white : Colors.black;
    final sub    = isDark ? Colors.white38 : Colors.black38;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('ORDER SUMMARY', isDark: isDark).animate().fadeIn(),
        const SizedBox(height: 16),

        // Items
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            children: List.generate(cart.items.length, (i) {
              final item = cart.items[i];
              final isLast = i == cart.items.length - 1;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.product.primaryImageUrl != null
                          ? Image.network(
                              item.product.fullPrimaryImageUrl,
                              width: 54, height: 54, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _ImgPlaceholder(isDark: isDark),
                            )
                          : _ImgPlaceholder(isDark: isDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.product.name,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Qty ${item.quantity}  ×  \$${_fmtPrice(item.product.price).substring(1)}',
                              style: TextStyle(fontSize: 12, color: sub)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('\$${_fmtPrice(item.itemTotal).substring(1)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ],
                ),
              );
            }),
          ),
        ).animate().fadeIn(delay: 40.ms),

        const SizedBox(height: 14),

        // Totals
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              _TotalRow('Subtotal', '\$${_fmtPrice(cart.subtotal).substring(1)}', fg: fg, sub: sub),
              const SizedBox(height: 10),
              _TotalRow('Shipping', 'Free', fg: AppColors.success, sub: sub),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: border),
              ),
              Row(
                children: [
                  Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
                  const Spacer(),
                  Text('\$${_fmtPrice(total).substring(1)}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.accent)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 60.ms),

        const SizedBox(height: 14),

        // Invoice notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
          ),
          child: const Row(
            children: [
              Icon(Icons.email_outlined, size: 15, color: AppColors.accent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'An invoice will be sent to your email once the order is placed.',
                  style: TextStyle(fontSize: 12, color: AppColors.accent, height: 1.5),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 80.ms),

        const SizedBox(height: 14),

        // Place Order button
        GestureDetector(
          onTap: placing ? null : onPlaceOrder,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              color: placing ? AppColors.accent.withValues(alpha: 0.55) : AppColors.accent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: placing ? [] : [
                BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: placing
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Place Order — \$${_fmtPrice(total).substring(1)}',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final Color fg, sub;
  const _TotalRow(this.label, this.value, {required this.fg, required this.sub});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: TextStyle(fontSize: 14, color: sub)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
    ],
  );
}

String _fmtPrice(double v) => '\$${v.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '')}';

// ─── Confirm Dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final double total;
  final String email;
  const _ConfirmDialog({required this.total, required this.email});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final border = isDark ? const Color(0xFF222) : const Color(0xFFE8E8E8);
    final fg     = isDark ? Colors.white : Colors.black;
    final sub    = isDark ? Colors.white60 : Colors.black54;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.1)),
              child: const Icon(Icons.receipt_long_outlined, color: AppColors.accent, size: 28),
            ),
            const SizedBox(height: 20),
            Text('Confirm Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 10),
            Text(
              'Your total is \$${_fmtPrice(total).substring(1)}.',
              style: TextStyle(fontSize: 14, color: sub, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined, size: 14, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Receipt will be emailed to\n$email',
                      style: const TextStyle(fontSize: 12, color: AppColors.accent, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                      child: Center(child: Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sub))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Center(child: Text('Place Order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.92, 0.92), duration: 220.ms, curve: Curves.easeOut).fadeIn();
  }
}

// ─── Map Picker Dialog ────────────────────────────────────────────────────────

class _PickedAddress {
  final String address, city, country, postal;
  const _PickedAddress({required this.address, required this.city, required this.country, required this.postal});
}

class _MapPickerDialog extends StatefulWidget {
  final String initialAddress, initialCity, initialCountry;
  const _MapPickerDialog({required this.initialAddress, required this.initialCity, required this.initialCountry});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  static const _istanbul = LatLng(41.0082, 28.9784);

  final _mapCtrl     = MapController();
  LatLng _center     = _istanbul;
  bool _geocoding    = false;
  Timer? _debounce;

  final _addrCtrl    = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _postalCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addrCtrl.text    = widget.initialAddress;
    _cityCtrl.text    = widget.initialCity;
    _countryCtrl.text = widget.initialCountry;

    if (widget.initialAddress.isNotEmpty || widget.initialCity.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _forwardGeocode());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addrCtrl.dispose(); _cityCtrl.dispose(); _countryCtrl.dispose(); _postalCtrl.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    final interactiveTypes = [
      MapEventSource.dragEnd,
      MapEventSource.flingAnimationController,
      MapEventSource.doubleTap,
      MapEventSource.scrollWheel,
    ];
    if (!interactiveTypes.contains(event.source)) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _reverseGeocode(_mapCtrl.camera.center);
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() { _center = pos; _geocoding = true; });
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 6)));
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {'lat': pos.latitude, 'lon': pos.longitude, 'format': 'jsonv2'},
        options: Options(headers: {'User-Agent': 'DroneHubApp/1.0'}),
      );
      final addr = (res.data['address'] as Map<String, dynamic>?) ?? {};
      if (mounted) {
        setState(() {
          _addrCtrl.text    = [addr['road'] ?? addr['pedestrian'] ?? addr['suburb'] ?? '', addr['house_number'] ?? '']
              .where((s) => s.isNotEmpty).join(' ');
          _cityCtrl.text    = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
          _countryCtrl.text = addr['country'] ?? '';
          _postalCtrl.text  = addr['postcode'] ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _geocoding = false);
  }

  Future<void> _forwardGeocode() async {
    final q = [widget.initialAddress, widget.initialCity, widget.initialCountry]
        .where((s) => s.isNotEmpty).join(', ');
    if (q.isEmpty) return;
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 6)));
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': q, 'format': 'json', 'limit': 1},
        options: Options(headers: {'User-Agent': 'DroneHubApp/1.0'}),
      );
      final results = res.data as List;
      if (results.isNotEmpty && mounted) {
        final lat = double.tryParse(results[0]['lat'].toString()) ?? _istanbul.latitude;
        final lon = double.tryParse(results[0]['lon'].toString()) ?? _istanbul.longitude;
        final pos = LatLng(lat, lon);
        setState(() => _center = pos);
        _mapCtrl.move(pos, 14);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final border  = isDark ? const Color(0xFF222) : const Color(0xFFE8E8E8);
    final fieldBg = isDark ? const Color(0xFF111) : const Color(0xFFF5F5F5);
    final fg      = isDark ? Colors.white : Colors.black;
    final sub     = isDark ? Colors.white54 : Colors.black45;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 680),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.1)),
                    child: const Icon(Icons.map_outlined, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Pick Delivery Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0)),
                      child: Icon(Icons.close_rounded, color: sub, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapCtrl,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: 12,
                          onMapEvent: _onMapEvent,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: isDark
                                ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                          ),
                        ],
                      ),
                      // Center pin
                      const IgnorePointer(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_pin, color: AppColors.accent, size: 44,
                                  shadows: [Shadow(blurRadius: 10, color: Colors.black54)]),
                              SizedBox(height: 22),
                            ],
                          ),
                        ),
                      ),
                      if (_geocoding)
                        Positioned(
                          top: 10, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                              child: const Text('Detecting location…', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Address fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _MapField(ctrl: _addrCtrl, hint: 'Street Address', isDark: isDark, fieldBg: fieldBg, border: border),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _MapField(ctrl: _cityCtrl, hint: 'City', isDark: isDark, fieldBg: fieldBg, border: border)),
                    const SizedBox(width: 10),
                    Expanded(child: _MapField(ctrl: _countryCtrl, hint: 'Country', isDark: isDark, fieldBg: fieldBg, border: border)),
                    const SizedBox(width: 10),
                    SizedBox(width: 100, child: _MapField(ctrl: _postalCtrl, hint: 'Postal', isDark: isDark, fieldBg: fieldBg, border: border)),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: () => Navigator.pop(context, _PickedAddress(
                  address: _addrCtrl.text,
                  city: _cityCtrl.text,
                  country: _countryCtrl.text,
                  postal: _postalCtrl.text,
                )),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Center(
                    child: Text('Confirm Location', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.95, 0.95), duration: 220.ms, curve: Curves.easeOut).fadeIn();
  }
}

class _MapField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool isDark;
  final Color fieldBg, border;
  const _MapField({required this.ctrl, required this.hint, required this.isDark, required this.fieldBg, required this.border});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
      filled: true, fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
      isDense: true,
    ),
  );
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white38 : Colors.black38, letterSpacing: 2),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isDark, required;
  final TextInputType? type;
  final int maxLines;

  const _Field({
    required this.ctrl, required this.label, required this.icon, required this.isDark,
    this.required = false, this.type, this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5);
    final border = isDark ? const Color(0xFF222222) : const Color(0xFFE0E0E0);
    final fg     = isDark ? Colors.white : Colors.black;
    final hint   = isDark ? Colors.white38 : Colors.black38;

    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14, color: fg),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hint, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: hint),
        filled: true, fillColor: bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        isDense: true,
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  final bool isDark;
  const _ImgPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    width: 54, height: 54,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.image_outlined, size: 22, color: isDark ? Colors.white24 : Colors.black26),
  );
}
