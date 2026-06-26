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

// Simple holder for images that already exist in the backend
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

  // Images already on the server (edit mode)
  final List<_ExistingImage> _existingImages = [];

  // Newly picked images (both modes)
  final List<XFile> _pickedFiles = [];
  final List<Uint8List> _pickedBytes = [];
  final _picker = ImagePicker();

  static const _kCurrencyKey = 'last_product_currency';
  static const _imgBase = 'http://10.155.83.72:5001';

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
    final saved = prefs.getString(_kCurrencyKey) ?? 'USD';
    if (mounted) setState(() => _currency = saved);
  }

  Future<void> _setCurrency(String c) async {
    setState(() => _currency = c);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_kCurrencyKey, c);
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
        // Show price as-is (preserve original decimals)
        final rawPrice = data['price'];
        _priceCtrl.text = rawPrice != null ? rawPrice.toString() : '';
        _stockCtrl.text = (data['stock'] ?? 0).toString();
        _brandCtrl.text = (data['brand'] as String?) ?? '';
        _category = data['category'] as String?;
        _isFeatured = (data['is_featured'] as bool?) ?? false;
        _currency = (data['currency'] as String?) ?? 'USD';

        // Load existing images sorted: primary first, then by sort_order
        _existingImages.clear();
        final imgs = List<Map<String, dynamic>>.from(data['images'] as List? ?? []);
        imgs.sort((a, b) {
          if (a['is_primary'] == true) return -1;
          if (b['is_primary'] == true) return 1;
          return ((a['sort_order'] as num?)?.toInt() ?? 0)
              .compareTo((b['sort_order'] as num?)?.toInt() ?? 0);
        });
        _existingImages.addAll(imgs.map((i) {
          final url = i['url'] as String;
          return _ExistingImage(
            i['id'] as String,
            url.startsWith('http') ? url : '$_imgBase$url',
          );
        }));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load product: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProduct = false);
    }
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final newBytes = await Future.wait(picked.map((f) => f.readAsBytes()));
    setState(() {
      _pickedFiles.addAll(picked);
      _pickedBytes.addAll(newBytes);
    });
  }

  void _removeNewImage(int i) {
    setState(() {
      _pickedFiles.removeAt(i);
      _pickedBytes.removeAt(i);
    });
  }

  Future<void> _removeExistingImage(String imageId) async {
    try {
      await ref.read(apiServiceProvider).delete('/admin/products/images/$imageId');
      setState(() => _existingImages.removeWhere((i) => i.id == imageId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Replace comma decimal separator with period before sending
      final priceText = _priceCtrl.text.trim().replaceAll(',', '.');

      final formData = FormData.fromMap({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'shortDescription': _shortDescCtrl.text.trim(),
        'price': priceText,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productId == null ? 'Product created!' : 'Product updated!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _descCtrl, _shortDescCtrl, _priceCtrl, _stockCtrl, _brandCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 900;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F8F8),
      body: Column(
        children: [
          _Header(isDark: isDark, isEdit: widget.productId != null),

          if (_loadingProduct)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _FormContent(
                            formKey: _formKey,
                            isDark: isDark,
                            nameCtrl: _nameCtrl,
                            descCtrl: _descCtrl,
                            shortDescCtrl: _shortDescCtrl,
                            priceCtrl: _priceCtrl,
                            stockCtrl: _stockCtrl,
                            brandCtrl: _brandCtrl,
                            category: _category,
                            isFeatured: _isFeatured,
                            saving: _saving,
                            isEdit: widget.productId != null,
                            currency: _currency,
                            onCurrencyChanged: _setCurrency,
                            onCategoryChanged: (v) => setState(() => _category = v),
                            onFeaturedChanged: (v) => setState(() => _isFeatured = v),
                            onSave: _save,
                            ref: ref,
                          ),
                        ),
                        SizedBox(
                          width: 340,
                          child: _ImagePanel(
                            isDark: isDark,
                            existingImages: _existingImages,
                            bytes: _pickedBytes,
                            onAdd: _pickImages,
                            onRemoveNew: _removeNewImage,
                            onRemoveExisting: _removeExistingImage,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _ImagePanel(
                            isDark: isDark,
                            existingImages: _existingImages,
                            bytes: _pickedBytes,
                            onAdd: _pickImages,
                            onRemoveNew: _removeNewImage,
                            onRemoveExisting: _removeExistingImage,
                            horizontal: true,
                          ),
                          _FormContent(
                            formKey: _formKey,
                            isDark: isDark,
                            nameCtrl: _nameCtrl,
                            descCtrl: _descCtrl,
                            shortDescCtrl: _shortDescCtrl,
                            priceCtrl: _priceCtrl,
                            stockCtrl: _stockCtrl,
                            brandCtrl: _brandCtrl,
                            category: _category,
                            isFeatured: _isFeatured,
                            saving: _saving,
                            isEdit: widget.productId != null,
                            currency: _currency,
                            onCurrencyChanged: _setCurrency,
                            onCategoryChanged: (v) => setState(() => _category = v),
                            onFeaturedChanged: (v) => setState(() => _isFeatured = v),
                            onSave: _save,
                            ref: ref,
                          ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isDark, isEdit;
  const _Header({required this.isDark, required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 16),
      color: isDark ? Colors.black : const Color(0xFFF8F8F8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black45),
                const SizedBox(width: 8),
                Text('Back', style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Text(
            isEdit ? 'Edit Product' : 'New Product',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
          ),
        ],
      ),
    );
  }
}

// ─── Image panel ──────────────────────────────────────────────────────────────

class _ImagePanel extends StatelessWidget {
  final bool isDark;
  final List<_ExistingImage> existingImages;
  final List<Uint8List> bytes;
  final VoidCallback onAdd;
  final void Function(int) onRemoveNew;
  final void Function(String) onRemoveExisting;
  final bool horizontal;

  const _ImagePanel({
    required this.isDark,
    required this.existingImages,
    required this.bytes,
    required this.onAdd,
    required this.onRemoveNew,
    required this.onRemoveExisting,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final total = existingImages.length + bytes.length;

    if (horizontal) {
      return Container(
        height: 130,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ..._buildThumbs(),
            _AddBtn(isDark: isDark, onTap: onAdd),
          ],
        ),
      );
    }

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text('Product Images', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._buildThumbs(),
                  _AddBtn(isDark: isDark, onTap: onAdd),
                ],
              ),
            ),
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                '$total image${total > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildThumbs() {
    final List<Widget> result = [];

    // Existing images from backend
    for (int i = 0; i < existingImages.length; i++) {
      final img = existingImages[i];
      final isMain = i == 0;
      result.add(
        Stack(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isMain ? AppColors.accent : Colors.transparent, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.network(
                  img.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_outlined, size: 32, color: isDark ? Colors.white24 : Colors.black26),
                ),
              ),
            ),
            if (isMain)
              Positioned(
                bottom: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3)),
                  child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                ),
              ),
            Positioned(
              top: 3, right: 3,
              child: GestureDetector(
                onTap: () => onRemoveExisting(img.id),
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Newly picked images (not yet uploaded)
    for (int i = 0; i < bytes.length; i++) {
      final isMain = existingImages.isEmpty && i == 0;
      result.add(
        Stack(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isMain ? AppColors.accent : Colors.transparent, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.memory(bytes[i], fit: BoxFit.contain),
              ),
            ),
            if (isMain)
              Positioned(
                bottom: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(3)),
                  child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                ),
              ),
            Positioned(
              top: 3, right: 3,
              child: GestureDetector(
                onTap: () => onRemoveNew(i),
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return result;
  }
}

class _AddBtn extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _AddBtn({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: AppColors.accent, size: 26),
            SizedBox(height: 4),
            Text('Add Photo', style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Form content ─────────────────────────────────────────────────────────────

class _FormContent extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final bool isDark, isFeatured, saving, isEdit;
  final TextEditingController nameCtrl, descCtrl, shortDescCtrl, priceCtrl, stockCtrl, brandCtrl;
  final String? category;
  final String currency;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<bool> onFeaturedChanged;
  final VoidCallback onSave;
  final WidgetRef ref;

  const _FormContent({
    required this.formKey, required this.isDark, required this.nameCtrl, required this.descCtrl,
    required this.shortDescCtrl, required this.priceCtrl,
    required this.stockCtrl, required this.brandCtrl, required this.category,
    required this.currency, required this.onCurrencyChanged,
    required this.isFeatured, required this.saving, required this.isEdit,
    required this.onCategoryChanged, required this.onFeaturedChanged,
    required this.onSave, required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef wref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _Section('Basic Info', isDark),

            _Field(ctrl: nameCtrl, label: 'Product Name', hint: 'e.g. T-Motor F40 PRO IV', isDark: isDark, validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: _Field(ctrl: brandCtrl, label: 'Brand', hint: 'e.g. T-Motor', isDark: isDark)),
              const SizedBox(width: 14),
              Expanded(
                child: ref.watch(_categoriesForFormProvider).when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  data: (cats) => _Dropdown(
                    label: 'Category',
                    value: category,
                    items: cats,
                    isDark: isDark,
                    onChanged: onCategoryChanged,
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 24),
            _Section('Description', isDark),

            _Field(ctrl: shortDescCtrl, label: 'Short Description', hint: 'One-liner summary', isDark: isDark, maxLines: 2),
            const SizedBox(height: 14),
            _Field(ctrl: descCtrl, label: 'Full Description', hint: 'Detailed product description', isDark: isDark, maxLines: 5, validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),

            const SizedBox(height: 24),
            _Section('Pricing & Stock', isDark),

            // Currency picker
            Row(
              children: [
                Text('Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45, letterSpacing: 0.5)),
                const SizedBox(width: 12),
                ...[('USD', '\$'), ('EUR', '€'), ('TRY', '₺')].map((pair) {
                  final selected = currency == pair.$1;
                  return GestureDetector(
                    onTap: () => onCurrencyChanged(pair.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : (isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: selected ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      ),
                      child: Text('${pair.$2} ${pair.$1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : (isDark ? Colors.white54 : Colors.black45))),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                child: _Field(
                  ctrl: priceCtrl,
                  label: 'Price',
                  hint: '0.00',
                  isDark: isDark,
                  prefix: currency == 'EUR' ? '€' : currency == 'TRY' ? '₺' : '\$',
                  // Text type to allow commas as decimal separator
                  keyboard: TextInputType.visiblePassword,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = double.tryParse(v.trim().replaceAll(',', '.'));
                    if (n == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Field(
                  ctrl: stockCtrl,
                  label: 'Stock',
                  hint: '0',
                  isDark: isDark,
                  keyboard: TextInputType.number,
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // Featured toggle
            GestureDetector(
              onTap: () => onFeaturedChanged(!isFeatured),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isFeatured ? AppColors.accent.withValues(alpha: 0.08) : (isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFeatured ? AppColors.accent.withValues(alpha: 0.4) : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                ),
                child: Row(
                  children: [
                    Icon(isFeatured ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: isFeatured ? AppColors.accent : (isDark ? Colors.white38 : Colors.black38)),
                    const SizedBox(width: 10),
                    Text('Featured Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isFeatured ? AppColors.accent : (isDark ? Colors.white54 : Colors.black54))),
                    const Spacer(),
                    Text('Show on homepage', style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            GestureDetector(
              onTap: saving ? null : onSave,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: saving ? AppColors.accent.withValues(alpha: 0.6) : AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(isEdit ? 'Update Product' : 'Create Product', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final bool isDark;
  const _Section(this.label, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 4),
        Container(height: 1, width: 40, color: AppColors.accent.withValues(alpha: 0.5)),
      ]),
    );
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

  const _Field({
    required this.ctrl, required this.label, required this.hint, required this.isDark,
    this.maxLines = 1, this.prefix, this.keyboard = TextInputType.text, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
          prefixText: prefix,
          filled: true,
          fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.error)),
        ),
      ),
    ]);
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<Map<String, String>> items;
  final bool isDark;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _Dropdown({required this.label, required this.value, required this.items, required this.isDark, required this.onChanged, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        validator: validator,
        dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.error)),
        ),
        items: items.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)))).toList(),
        onChanged: onChanged,
      ),
    ]);
  }
}