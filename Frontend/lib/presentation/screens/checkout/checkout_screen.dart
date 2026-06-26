import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/order_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';

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
  late final TextEditingController _addr2Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _postalCtrl;
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _addr1Ctrl = TextEditingController(text: user?.addressLine1 ?? '');
    _addr2Ctrl = TextEditingController(text: user?.addressLine2 ?? '');
    _cityCtrl = TextEditingController(text: user?.city ?? '');
    _stateCtrl = TextEditingController(text: user?.state ?? '');
    _countryCtrl = TextEditingController(text: user?.country ?? '');
    _postalCtrl = TextEditingController(text: user?.postalCode ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _phoneCtrl, _addr1Ctrl, _addr2Ctrl, _cityCtrl, _stateCtrl, _countryCtrl, _postalCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (cart) {
          final shippingCost = cart.subtotal >= 100 ? 0.0 : 9.99;
          final tax = cart.subtotal * 0.18;
          final total = cart.subtotal + shippingCost + tax;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shipping Address', style: Theme.of(context).textTheme.titleLarge).animate().fadeIn(),
                  const SizedBox(height: 16),

                  _buildField(_nameCtrl, 'Full Name', Icons.person_outline, required: true),
                  _buildField(_emailCtrl, 'Email', Icons.email_outlined, required: true, type: TextInputType.emailAddress),
                  _buildField(_phoneCtrl, 'Phone', Icons.phone_outlined, type: TextInputType.phone),
                  _buildField(_addr1Ctrl, 'Address Line 1', Icons.location_on_outlined, required: true),
                  _buildField(_addr2Ctrl, 'Address Line 2 (optional)', Icons.location_on_outlined),
                  Row(
                    children: [
                      Expanded(child: _buildField(_cityCtrl, 'City', Icons.location_city_outlined, required: true, noPadding: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_stateCtrl, 'State', Icons.map_outlined, noPadding: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildField(_countryCtrl, 'Country', Icons.flag_outlined, required: true, noPadding: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_postalCtrl, 'Postal Code', Icons.markunread_mailbox_outlined, noPadding: true)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Order Notes (optional)', prefixIcon: Icon(Icons.notes_outlined, size: 20)),
                  ),

                  const SizedBox(height: 28),
                  Text('Order Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),

                  _SummaryCard(
                    subtotal: cart.subtotal,
                    shippingCost: shippingCost,
                    tax: tax,
                    total: total,
                    itemCount: cart.itemCount,
                  ),

                  const SizedBox(height: 24),

                  // Payment note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card_outlined, color: AppColors.info, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text('Demo mode: No real payment required', style: TextStyle(color: AppColors.info, fontSize: 13))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Place Order — \$${total.toStringAsFixed(2)}',
                    isLoading: _placing,
                    onPressed: () => _placeOrder(total),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool required = false, TextInputType? type, bool noPadding = false}) {
    final field = TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null,
    );
    if (noPadding) return field;
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: field);
  }

  Future<void> _placeOrder(double total) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _placing = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final address = ShippingAddress(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        addressLine1: _addr1Ctrl.text.trim(),
        addressLine2: _addr2Ctrl.text.trim().isEmpty ? null : _addr2Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim().isEmpty ? null : _postalCtrl.text.trim(),
      );
      final order = await repo.createOrder(address, notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim());
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
}

class _SummaryCard extends StatelessWidget {
  final double subtotal, shippingCost, tax, total;
  final int itemCount;
  const _SummaryCard({required this.subtotal, required this.shippingCost, required this.tax, required this.total, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          _Row('Items ($itemCount)', '\$${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _Row('Shipping', shippingCost == 0 ? 'FREE' : '\$${shippingCost.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _Row('Tax (18%)', '\$${tax.toStringAsFixed(2)}'),
          const Divider(height: 20),
          _Row('Total', '\$${total.toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: bold ? AppColors.accent : null, fontSize: bold ? 16 : 14)),
        ],
      );
}
