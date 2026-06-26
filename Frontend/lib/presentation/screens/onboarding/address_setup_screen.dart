import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api_service.dart';
import '../../providers/auth_provider.dart';

enum _TileMode { light, dark, satellite }

class AddressSetupScreen extends ConsumerStatefulWidget {
  const AddressSetupScreen({super.key});

  @override
  ConsumerState<AddressSetupScreen> createState() => _AddressSetupScreenState();
}

class _AddressSetupScreenState extends ConsumerState<AddressSetupScreen> {
  final _mapController = MapController();
  final _searchCtrl   = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _countryCtrl  = TextEditingController();
  final _postalCtrl   = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _TileMode _tileMode = _TileMode.light;
  LatLng _center = const LatLng(41.0082, 28.9784); // Istanbul
  double _zoom = 11;

  bool _locating = false;
  bool _geocoding = false;
  bool _saving = false;

  // Search results
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _phoneCtrl.text = user?.phone ?? '';
    // Try GPS immediately if already permitted
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoLocate());
  }

  Future<void> _tryAutoLocate() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        await _useMyLocation();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _postalCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ─── Tile URLs ─────────────────────────────────────────────────────────────

  String get _tileUrl {
    switch (_tileMode) {
      case _TileMode.light:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _TileMode.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case _TileMode.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  List<String>? get _subdomains =>
      _tileMode == _TileMode.dark ? ['a', 'b', 'c', 'd'] : null;

  // ─── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      _mapController.move(ll, 15);
      setState(() => _center = ll);
      await _reverseGeocode(ll);
    } catch (e) {
      _showSnack('Could not get location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ─── Reverse geocoding ─────────────────────────────────────────────────────

  Future<void> _reverseGeocode(LatLng ll) async {
    setState(() => _geocoding = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {'format': 'jsonv2', 'lat': ll.latitude, 'lon': ll.longitude, 'accept-language': 'en'},
        options: Options(headers: {'User-Agent': 'DroneHub/1.0'}),
      );
      final addr = res.data['address'] as Map<String, dynamic>? ?? {};
      final road = [
        addr['house_number'],
        addr['road'] ?? addr['pedestrian'] ?? addr['street'],
      ].whereType<String>().join(' ').trim();
      final city    = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? '';
      final country = addr['country'] ?? '';
      final postal  = addr['postcode'] ?? '';
      setState(() {
        _addressCtrl.text = road;
        _cityCtrl.text    = city;
        _countryCtrl.text = country;
        _postalCtrl.text  = postal;
        _center = ll;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  // ─── Forward geocoding (search) ────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _searchAddress(q.trim()));
  }

  Future<void> _searchAddress(String q) async {
    setState(() => _searching = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'format': 'json', 'q': q, 'limit': '5', 'accept-language': 'en'},
        options: Options(headers: {'User-Agent': 'DroneHub/1.0'}),
      );
      final results = (res.data as List).cast<Map<String, dynamic>>();
      setState(() { _searchResults = results; _searching = false; });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  void _selectSearchResult(Map<String, dynamic> r) {
    final lat = double.tryParse(r['lat'].toString()) ?? 0;
    final lon = double.tryParse(r['lon'].toString()) ?? 0;
    final ll = LatLng(lat, lon);
    _mapController.move(ll, 14);
    setState(() { _searchResults = []; _searchCtrl.clear(); });
    _reverseGeocode(ll);
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final city    = _cityCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (address.isEmpty && city.isEmpty) {
      _showSnack('Please select your location on the map first.');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.put('/users/profile', data: {
        'phone':        _phoneCtrl.text.trim(),
        'addressLine1': address,
        'city':         city,
        'country':      _countryCtrl.text.trim(),
        'postalCode':   _postalCtrl.text.trim(),
      });
      final d = (res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      ref.read(authProvider.notifier).updateUser(
        ref.read(authProvider).user!.copyWith(
          phone:        d['phone'],
          addressLine1: d['address_line1'],
          city:         d['city'],
          country:      d['country'],
          postalCode:   d['postal_code'],
        ),
      );
      final pending = ref.read(authProvider).pendingRedirect;
      ref.read(authProvider.notifier).completeOnboarding();
      ref.read(authProvider.notifier).clearPendingRedirect();
      if (mounted) context.go(pending ?? '/');
    } catch (e) {
      _showSnack('Failed to save: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() {
    final pending = ref.read(authProvider).pendingRedirect;
    ref.read(authProvider.notifier).completeOnboarding();
    ref.read(authProvider.notifier).clearPendingRedirect();
    context.go(pending ?? '/');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Force light map on light theme
    if (!isDark && _tileMode == _TileMode.dark) _tileMode = _TileMode.light;
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F8F8),
      body: isWide ? _buildWide(isDark) : _buildNarrow(isDark),
    );
  }

  Widget _buildWide(bool isDark) {
    return Row(children: [
      Expanded(flex: 3, child: _buildMapPanel(isDark)),
      SizedBox(width: 380, child: _buildFormPanel(isDark)),
    ]);
  }

  Widget _buildNarrow(bool isDark) {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: SizedBox(height: 360, child: _buildMapPanel(isDark))),
      SliverPadding(padding: const EdgeInsets.all(24), sliver: SliverToBoxAdapter(child: _buildForm(isDark))),
    ]);
  }

  // ─── Map panel ─────────────────────────────────────────────────────────────

  Widget _buildMapPanel(bool isDark) {
    return Stack(children: [
      // Map
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _zoom,
          onMapEvent: (event) {
            // Only react to user-initiated map movement, not programmatic moves
            if (event is MapEventMoveEnd &&
                (event.source == MapEventSource.dragEnd ||
                 event.source == MapEventSource.flingAnimationController ||
                 event.source == MapEventSource.doubleTap ||
                 event.source == MapEventSource.doubleTapZoomAnimationController ||
                 event.source == MapEventSource.scrollWheel)) {
              final c = event.camera.center;
              setState(() => _center = c);
              _reverseGeocode(c);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: _tileUrl,
            subdomains: _subdomains ?? const [],
            userAgentPackageName: 'com.dronehub.app',
            maxZoom: 19,
          ),
        ],
      ),

      // Center marker (always centered, doesn't move with map)
      const Center(child: _CenterMarker()),

      // Search bar at top
      Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16, right: 16,
        child: _buildSearchBar(isDark),
      ),

      // Tile mode buttons
      Positioned(
        bottom: 80, right: 16,
        child: _buildTileModeButtons(isDark),
      ),

      // GPS button
      Positioned(
        bottom: 16, right: 16,
        child: _GpsButton(loading: _locating, onTap: _useMyLocation, isDark: isDark),
      ),

      // Geocoding indicator
      if (_geocoding)
        Positioned(
          bottom: 16, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
              SizedBox(width: 8),
              Text('Finding address…', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
    ]);
  }

  Widget _buildSearchBar(bool isDark) {
    final bg = isDark ? const Color(0xFF111) : Colors.white;
    final shadow = BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12), blurRadius: 16, offset: const Offset(0, 4));

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), boxShadow: [shadow]),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Search or paste an address…',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
              suffixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)))
                  : (_searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchResults = []); })
                      : null),
              filled: true, fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), boxShadow: [shadow]),
            child: Column(
              children: _searchResults.map((r) {
                return InkWell(
                  onTap: () => _selectSearchResult(r),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.location_on_outlined, size: 16, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r['display_name']?.toString() ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTileModeButtons(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
      ),
      child: Column(
        children: [
          _TileBtn(icon: Icons.wb_sunny_outlined, label: 'Light', active: _tileMode == _TileMode.light, isDark: isDark, onTap: () => setState(() => _tileMode = _TileMode.light)),
          _TileBtn(icon: Icons.nights_stay_outlined, label: 'Dark', active: _tileMode == _TileMode.dark, isDark: isDark, onTap: () => setState(() => _tileMode = _TileMode.dark)),
          _TileBtn(icon: Icons.satellite_alt_outlined, label: 'Satellite', active: _tileMode == _TileMode.satellite, isDark: isDark, onTap: () => setState(() => _tileMode = _TileMode.satellite), isLast: true),
        ],
      ),
    );
  }

  // ─── Form panel ────────────────────────────────────────────────────────────

  Widget _buildFormPanel(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080808) : Colors.white,
        border: Border(left: BorderSide(color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8))),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32, MediaQuery.of(context).padding.top + 32, 32, 32),
        child: _buildForm(isDark),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    final detectedAddr = [_addressCtrl.text, _cityCtrl.text, _countryCtrl.text].where((s) => s.isNotEmpty).join(', ');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
              children: const [TextSpan(text: 'Drone'), TextSpan(text: 'Hub', style: TextStyle(color: AppColors.accent))],
            ),
          ),
          const SizedBox(height: 20),
          Text('Set up your address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 6),
          Text('Move the map to your location or search for your address.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38, height: 1.5)),

          const SizedBox(height: 28),

          // Detected address preview
          if (detectedAddr.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(detectedAddr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.accent))),
              ]),
            ).animate().fadeIn(),
            const SizedBox(height: 20),
          ],

          _label('Phone Number', isDark),
          const SizedBox(height: 8),
          _field(ctrl: _phoneCtrl, hint: '+9X XX XXX XXXX', icon: Icons.phone_outlined, isDark: isDark, keyboard: TextInputType.phone),

          const SizedBox(height: 16),
          _label('Street Address', isDark),
          const SizedBox(height: 8),
          _field(ctrl: _addressCtrl, hint: 'Auto-filled from map…', icon: Icons.location_on_outlined, isDark: isDark),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('City', isDark),
              const SizedBox(height: 8),
              _field(ctrl: _cityCtrl, hint: 'City', icon: Icons.location_city_outlined, isDark: isDark),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Postal Code', isDark),
              const SizedBox(height: 8),
              _field(ctrl: _postalCtrl, hint: 'Postal', isDark: isDark, keyboard: TextInputType.number),
            ])),
          ]),

          const SizedBox(height: 16),
          _label('Country', isDark),
          const SizedBox(height: 8),
          _field(ctrl: _countryCtrl, hint: 'Country', icon: Icons.flag_outlined, isDark: isDark),

          const SizedBox(height: 32),

          // Save button
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _saving ? AppColors.accent.withValues(alpha: 0.6) : AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Skip
          GestureDetector(
            onTap: _skip,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF222) : const Color(0xFFDDD)),
              ),
              child: Center(
                child: Text('Skip for now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white38 : Colors.black38)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, bool isDark) => Text(
    text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: isDark ? Colors.white38 : Colors.black38),
  );

  Widget _field({
    required TextEditingController ctrl,
    String hint = '',
    IconData? icon,
    bool isDark = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: isDark ? Colors.white30 : Colors.black26) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF111) : const Color(0xFFF5F5F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

// ─── Center marker widget ─────────────────────────────────────────────────────

class _CenterMarker extends StatelessWidget {
  const _CenterMarker();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Outer pulsing ring
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Center(
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)],
                ),
              ),
            ),
          ),
          // Stem
          Container(width: 2, height: 10, color: AppColors.accent),
          // Dot at bottom
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent)),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1200.ms, curve: Curves.easeInOut);
  }
}

// ─── GPS button ───────────────────────────────────────────────────────────────

class _GpsButton extends StatelessWidget {
  final bool loading, isDark;
  final VoidCallback onTap;
  const _GpsButton({required this.loading, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: loading
            ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            : const Icon(Icons.my_location_rounded, size: 22, color: AppColors.accent),
      ),
    );
  }
}

// ─── Tile mode button ─────────────────────────────────────────────────────────

class _TileBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active, isDark, isLast;
  final VoidCallback onTap;
  const _TileBtn({required this.icon, required this.label, required this.active, required this.isDark, required this.onTap, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: isLast ? const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)) : BorderRadius.zero,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? AppColors.accent : (isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.accent : (isDark ? Colors.white54 : Colors.black45))),
        ]),
      ),
    );
  }
}