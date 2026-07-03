import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api_service.dart';

final _categoriesForFormProvider = FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final res = await ref.watch(apiServiceProvider).get('/admin/categories');
  final data = (res.data as Map<String, dynamic>)['data'] as List;
  return data.map((c) => {'value': c['slug'] as String, 'label': c['name'] as String}).toList();
});

class _ExistingImage {
  final String id;
  final String url;
  const _ExistingImage(this.id, this.url);
}

class AdminAddProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AdminAddProductScreen({super.key, this.productId});

  @override
  ConsumerState<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends ConsumerState<AdminAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _loadingProduct = false;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _brandCtrl = TextEditingController();

  String? _category;
  bool _isFeatured = false;
  String _currency = 'USD';

  final List<_ExistingImage> _existingImages = [];
  final List<XFile> _pickedFiles = [];
  final List<Uint8List> _pickedBytes = [];
  final _picker = ImagePicker();

  static const _kCurrencyKey = 'last_product_currency';
  static const _imgBase = 'http://localhost:5001';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    if (widget.productId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
    }
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _currency = prefs.getString(_kCurrencyKey) ?? 'USD');
  }

  Future<void> _setCurrency(String c) async {
    setState(() => _currency = c);
    (await SharedPreferences.getInstance()).setString(_kCurrencyKey, c);
  }

  Future<void> _loadProduct() async {
    setState(() => _loadingProduct = true);
    try {
      final res = await ref.read(apiServiceProvider).get('/admin/products/${widget.productId}');
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      setState(() {
        _nameCtrl.text = (data['name'] as String?) ?? '';
        _descCtrl.text = (data['description'] as String?) ?? '';
        _shortDescCtrl.text = (data['short_description'] as String?) ?? '';
        _priceCtrl.text = data['price']?.toString() ?? '';
        _stockCtrl.text = (data['stock'] ?? 0).toString();
        _brandCtrl.text = (data['brand'] as String?) ?? '';
        _category = data['category'] as String?;
        _isFeatured = (data['is_featured'] as bool?) ?? false;
        _currency = (data['currency'] as String?) ?? 'USD';
        _existingImages.clear();
        final imgs = List<Map<String, dynamic>>.from(data['images'] as List? ?? []);
        imgs.sort((a, b) {
          if (a['is_primary'] == true) return -1;
          if (b['is_primary'] == true) return 1;
          return ((a['sort_order'] as num?)?.toInt() ?? 0).compareTo((b['sort_order'] as num?)?.toInt() ?? 0);
        });
        _existingImages.addAll(imgs.map((i) {
          final url = i['url'] as String;
          return _ExistingImage(i['id'] as String, url.startsWith('http') ? url : '$_imgBase$url');
        }));
      });
    } catch (e) {
      if (mounted) _showError('Failed to load product: $e');
    } finally {
      if (mounted) setState(() => _loadingProduct = false);
    }
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final bytes = await Future.wait(picked.map((f) => f.readAsBytes()));
    setState(() { _pickedFiles.addAll(picked); _pickedBytes.addAll(bytes); });
  }

  void _removeNew(int i) => setState(() { _pickedFiles.removeAt(i); _pickedBytes.removeAt(i); });

  Future<void> _removeExisting(String imageId) async {
    try {
      await ref.read(apiServiceProvider).delete('/admin/products/images/$imageId');
      setState(() => _existingImages.removeWhere((i) => i.id == imageId));
    } catch (e) { _showError('Failed to delete image: $e'); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  void _showSuccessOverlay() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _SuccessToast(
      name: _nameCtrl.text.trim(),
      isEdit: widget.productId != null,
      onDone: () { if (entry.mounted) entry.remove(); },
    ));
    overlay.insert(entry);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final formData = FormData.fromMap({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'shortDescription': _shortDescCtrl.text.trim(),
        'price': _priceCtrl.text.trim().replaceAll(',', '.'),
        'stock': _stockCtrl.text.trim(),
        'category': _category ?? 'accessories',
        'brand': _brandCtrl.text.trim(),
        'currency': _currency,
        'isFeatured': _isFeatured.toString(),
      });
      for (int i = 0; i < _pickedFiles.length; i++) {
        formData.files.add(MapEntry('images', MultipartFile.fromBytes(_pickedBytes[i], filename: _pickedFiles[i].name)));
      }
      final api = ref.read(apiServiceProvider);
      if (widget.productId == null) {
        await api.postForm('/admin/products', formData);
      } else {
        await api.putForm('/admin/products/${widget.productId}', formData);
      }
      if (mounted) {
        _showSuccessOverlay();
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) context.pop();
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _shortDescCtrl, _priceCtrl, _stockCtrl, _brandCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 860;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Column(
          children: [
            _FormHeader(isDark: isDark, isEdit: widget.productId != null, saving: _saving, onSave: _saving ? null : _save),
            if (_loadingProduct)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
            else
              Expanded(
                child: isWide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 58, child: _buildForm(isDark)),
                        Container(width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        SizedBox(width: 320, child: _ImagePanel(isDark: isDark, existingImages: _existingImages, bytes: _pickedBytes, onAdd: _pickImages, onRemoveNew: _removeNew, onRemoveExisting: _removeExisting)),
                      ])
                    : _buildForm(isDark, withImages: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, {bool withImages = false}) {
    final cats = ref.watch(_categoriesForFormProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (withImages) ...[
              _ImagePanel(isDark: isDark, existingImages: _existingImages, bytes: _pickedBytes, onAdd: _pickImages, onRemoveNew: _removeNew, onRemoveExisting: _removeExisting, inline: true),
              const SizedBox(height: 20),
            ],

            // ── Basic info card
            _Card(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionLabel('Product Identity', isDark),
              const SizedBox(height: 14),
              _Field(ctrl: _nameCtrl, label: 'Product Name', hint: 'e.g. T-Motor F40 PRO IV', isDark: isDark, validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
              const SizedBox(height: 14),
              _Field(ctrl: _brandCtrl, label: 'Brand', hint: 'e.g. T-Motor', isDark: isDark),
              const SizedBox(height: 14),
              cats.when(
                loading: () => const _LoadingChips(),
                error: (_, __) => const Text('Failed to load categories', style: TextStyle(color: AppColors.error, fontSize: 12)),
                data: (list) => _CategoryChipPicker(
                  categories: list,
                  selected: _category,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => v == null ? 'Select a category' : null,
                ),
              ),
            ])),

            const SizedBox(height: 14),

            // ── Description card
            _Card(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionLabel('Description', isDark),
              const SizedBox(height: 14),
              _Field(ctrl: _shortDescCtrl, label: 'Short Description', hint: 'One-liner shown on product cards', isDark: isDark, maxLines: 2),
              const SizedBox(height: 14),
              _Field(ctrl: _descCtrl, label: 'Full Description', hint: 'Detailed product info, specs, use cases...', isDark: isDark, maxLines: 6, validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            ])),

            const SizedBox(height: 14),

            // ── Pricing card
            _Card(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionLabel('Pricing & Stock', isDark),
              const SizedBox(height: 14),
              // Currency chips
              Row(children: [
                Text('Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: isDark ? Colors.white54 : Colors.black45)),
                const SizedBox(width: 12),
                ...([('USD', '\$'), ('EUR', '€'), ('TRY', '₺')].map((pair) {
                  final sel = _currency == pair.$1;
                  return GestureDetector(
                    onTap: () => _setCurrency(pair.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accent : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE)),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: sel ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      ),
                      child: Text('${pair.$2} ${pair.$1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isDark ? Colors.white54 : Colors.black45))),
                    ),
                  );
                })),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Field(
                  ctrl: _priceCtrl, label: 'Price', hint: '0.00', isDark: isDark,
                  prefix: _currency == 'EUR' ? '€' : _currency == 'TRY' ? '₺' : '\$',
                  keyboard: TextInputType.visiblePassword,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim().replaceAll(',', '.')) == null) return 'Invalid number';
                    return null;
                  },
                )),
                const SizedBox(width: 14),
                Expanded(child: _Field(ctrl: _stockCtrl, label: 'Stock Quantity', hint: '0', isDark: isDark, keyboard: TextInputType.number, validator: (v) => v?.trim().isEmpty == true ? 'Required' : null)),
              ]),
            ])),

            const SizedBox(height: 14),

            // ── Settings card
            _Card(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionLabel('Settings', isDark),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => setState(() => _isFeatured = !_isFeatured),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isFeatured ? AppColors.accent.withValues(alpha: 0.08) : (isDark ? const Color(0xFF151515) : const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isFeatured ? AppColors.accent.withValues(alpha: 0.45) : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _isFeatured ? AppColors.accent.withValues(alpha: 0.15) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_isFeatured ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: _isFeatured ? AppColors.accent : (isDark ? Colors.white38 : Colors.black38)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Featured on Homepage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _isFeatured ? AppColors.accent : (isDark ? Colors.white : Colors.black))),
                      const SizedBox(height: 2),
                      Text('Appears in the Bento Grid on the home screen', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                    ])),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40, height: 22,
                      decoration: BoxDecoration(
                        color: _isFeatured ? AppColors.accent : (isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: _isFeatured ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ])),

            const SizedBox(height: 28),

            // Save button
            GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 52,
                decoration: BoxDecoration(
                  color: _saving ? AppColors.accent.withValues(alpha: 0.6) : AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _saving ? [] : [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(widget.productId == null ? 'Create Product' : 'Update Product', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2)),
                        ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Premium success overlay ─────────────────────────────────────────────────

class _SuccessToast extends StatefulWidget {
  final String name;
  final bool isEdit;
  final VoidCallback onDone;
  const _SuccessToast({required this.name, required this.isEdit, required this.onDone});

  @override
  State<_SuccessToast> createState() => _SuccessToastState();
}

class _SuccessToastState extends State<_SuccessToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _ctrl.reverse().then((_) => widget.onDone());
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(color: AppColors.success.withValues(alpha: 0.2), blurRadius: 28, spreadRadius: 2),
                  const BoxShadow(color: Color(0xFF000000), blurRadius: 20, offset: Offset(0, 8)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.check_rounded, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.isEdit ? 'Product Updated' : 'Product Created', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(widget.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: const Text('SAVED', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Form header ─────────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  final bool isDark, isEdit, saving;
  final VoidCallback? onSave;
  const _FormHeader({required this.isDark, required this.isEdit, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : const Color(0xFFF7F7F9),
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Row(children: [
            Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 6),
            Text('Products', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
          ]),
        ),
        const SizedBox(width: 16),
        const Text('/', style: TextStyle(color: Colors.grey)),
        const SizedBox(width: 16),
        Text(isEdit ? 'Edit Product' : 'New Product', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
        const Spacer(),
        GestureDetector(
          onTap: onSave,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: saving ? AppColors.accent.withValues(alpha: 0.6) : AppColors.accent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(isEdit ? 'Update' : 'Publish', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}

// ─── Category chip picker ─────────────────────────────────────────────────────

class _CategoryChipPicker extends StatefulWidget {
  final List<Map<String, String>> categories;
  final String? selected;
  final bool isDark;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  const _CategoryChipPicker({required this.categories, required this.selected, required this.isDark, required this.onChanged, this.validator});

  @override
  State<_CategoryChipPicker> createState() => _CategoryChipPickerState();
}

class _CategoryChipPickerState extends State<_CategoryChipPicker> {
  final _searchCtrl = TextEditingController();
  String _filter = '';
  bool _open = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  String? get _selectedLabel => widget.categories.where((c) => c['value'] == widget.selected).map((c) => c['label']!).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? widget.categories
        : widget.categories.where((c) => c['label']!.toLowerCase().contains(_filter)).toList();

    return FormField<String>(
      validator: widget.validator,
      initialValue: widget.selected,
      builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: widget.isDark ? Colors.white60 : Colors.black54)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: field.hasError
                    ? AppColors.error
                    : (_open ? AppColors.accent : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                width: _open ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              if (_selectedLabel != null) ...[
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                const SizedBox(width: 9),
                Text(_selectedLabel!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black)),
              ] else
                Text('Select a category', style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white30 : Colors.black38)),
              const Spacer(),
              Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: widget.isDark ? Colors.white38 : Colors.black38),
            ]),
          ),
        ),
        if (field.hasError)
          Padding(padding: const EdgeInsets.only(top: 5, left: 2), child: Text(field.errorText!, style: const TextStyle(color: AppColors.error, fontSize: 11))),
        if (_open) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Search categories...',
              hintStyle: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white30 : Colors.black38),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.accent),
              filled: true,
              fillColor: widget.isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.accent, width: 1)),
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No categories found', style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white30 : Colors.black38)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filtered.map((c) {
                final sel = c['value'] == widget.selected;
                return GestureDetector(
                  onTap: () {
                    widget.onChanged(c['value']);
                    field.didChange(c['value']);
                    setState(() { _open = false; _filter = ''; _searchCtrl.clear(); });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.accent : (widget.isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE)),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: sel ? AppColors.accent : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                    ),
                    child: Text(c['label']!, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black54))),
                  ),
                );
              }).toList(),
            ),
        ],
      ]),
    );
  }
}

class _LoadingChips extends StatelessWidget {
  const _LoadingChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: List.generate(5, (i) => Container(
      width: 60 + (i % 3) * 20.0,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(7),
      ),
    )));
  }
}

// ─── Image panel ─────────────────────────────────────────────────────────────

class _ImagePanel extends StatelessWidget {
  final bool isDark;
  final List<_ExistingImage> existingImages;
  final List<Uint8List> bytes;
  final VoidCallback onAdd;
  final void Function(int) onRemoveNew;
  final void Function(String) onRemoveExisting;
  final bool inline;

  const _ImagePanel({
    required this.isDark, required this.existingImages, required this.bytes,
    required this.onAdd, required this.onRemoveNew, required this.onRemoveExisting,
    this.inline = false,
  });

  int get _total => existingImages.length + bytes.length;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0C0C0C) : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (inline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [..._thumbs(), const SizedBox(width: 8), _addBtn()]),
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(color: bg, border: Border(left: BorderSide(color: border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 14), child: _label()),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Wrap(spacing: 10, runSpacing: 10, children: [..._thumbs(), _addBtn()]),
          ),
        ),
        if (_total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text('$_total image${_total > 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black38)),
          ),
      ]),
    );
  }

  Widget _label() => Row(children: [
    const Icon(Icons.photo_library_outlined, size: 14, color: AppColors.accent),
    const SizedBox(width: 7),
    Text('Product Images', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54)),
  ]);

  Widget _addBtn() => GestureDetector(
    onTap: onAdd,
    child: Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28), style: BorderStyle.solid),
      ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_photo_alternate_outlined, color: AppColors.accent, size: 24),
        SizedBox(height: 5),
        Text('Add Photo', style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    ),
  );

  List<Widget> _thumbs() {
    final result = <Widget>[];
    for (int i = 0; i < existingImages.length; i++) {
      final img = existingImages[i];
      result.add(_Thumb(isMain: i == 0, onRemove: () => onRemoveExisting(img.id), child: Image.network(img.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 28, color: Colors.white24))));
    }
    for (int i = 0; i < bytes.length; i++) {
      final isMain = existingImages.isEmpty && i == 0;
      result.add(_Thumb(isMain: isMain, onRemove: () => onRemoveNew(i), child: Image.memory(bytes[i], fit: BoxFit.cover)));
    }
    return result;
  }
}

class _Thumb extends StatelessWidget {
  final bool isMain;
  final VoidCallback onRemove;
  final Widget child;
  const _Thumb({required this.isMain, required this.onRemove, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: isMain ? AppColors.accent : Colors.transparent, width: 2),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
      ),
      if (isMain)
        Positioned(bottom: 4, left: 4, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3)),
          child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
        )),
      Positioned(top: 3, right: 3, child: GestureDetector(
        onTap: onRemove,
        child: Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 12, color: Colors.white),
        ),
      )),
    ]);
  }
}

// ─── UI helpers ───────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _Card({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel(this.label, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: isDark ? Colors.white : Colors.black)),
    ]);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool isDark;
  final int maxLines;
  final String? prefix;
  final TextInputType keyboard;
  final String? Function(String?)? validator;

  const _Field({required this.ctrl, required this.label, required this.hint, required this.isDark, this.maxLines = 1, this.prefix, this.keyboard = TextInputType.text, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: isDark ? Colors.white60 : Colors.black54)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, maxLines: maxLines, keyboardType: keyboard, validator: validator,
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
          prefixText: prefix,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8F8F8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.error)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        ),
      ),
    ]);
  }
}
