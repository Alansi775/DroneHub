import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product/product_card.dart';
import '../../widgets/common/loading_shimmer.dart';

final _featuredProvider = FutureProvider<List<ProductModel>>((ref) async {
  final res = await ref.watch(productRepositoryProvider).getProducts(featured: true, limit: 6);
  return res.products;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: CustomScrollView(
        slivers: [
          // Navbar space
          const SliverToBoxAdapter(child: SizedBox(height: 80)),

          // 1 — Static DJI hero (text + gradient)
          SliverToBoxAdapter(child: _StaticHero(isDark: isDark)),

          // 2 — Bento grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: _BentoGrid(isDark: isDark),
            ),
          ),

          // 3 — Video carousel section
          SliverToBoxAdapter(child: _VideoSection(isDark: isDark)),

          // 4 — Featured products
          SliverToBoxAdapter(child: _SectionHeader(isDark: isDark)),
          _ProductsGrid(),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── 1. Static Hero ───────────────────────────────────────────────────────────

class _StaticHero extends StatelessWidget {
  final bool isDark;
  const _StaticHero({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Container(
      height: h * 0.78,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, 0.2),
          radius: 0.9,
          colors: [
            isDark ? const Color(0xFF0D1520) : const Color(0xFFE8F0FA),
            isDark ? Colors.black : Colors.white,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Professional Drone Components',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white54 : Colors.black38,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 12),

          Text(
            'Build The\nPerfect Drone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _fs(w, 80, 64, 48, 36),
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -2,
              height: 1.0,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, curve: Curves.easeOut),

          const SizedBox(height: 14),

          Text(
            'Everything you need. Nothing you don\'t.',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w300,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PillBtn(label: 'Shop Now', filled: true, onTap: () => context.go('/products')),
              const SizedBox(width: 12),
              _PillBtn(label: 'View Featured', filled: false, isDark: isDark, onTap: () => context.go('/products?featured=true')),
            ],
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  double _fs(double w, double xl, double lg, double md, double sm) {
    if (w > 1400) return xl;
    if (w > 900) return lg;
    if (w > 600) return md;
    return sm;
  }
}

class _PillBtn extends StatelessWidget {
  final String label;
  final bool filled;
  final bool isDark;
  final VoidCallback onTap;
  const _PillBtn({required this.label, required this.filled, this.isDark = true, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : (isDark ? Colors.white : Colors.black);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.transparent,
          border: Border.all(
            color: filled ? AppColors.accent : (isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.22)),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: fg),
          ],
        ),
      ),
    );
  }
}

// ─── 2. Bento Grid ────────────────────────────────────────────────────────────

class _BentoGrid extends ConsumerWidget {
  final bool isDark;
  const _BentoGrid({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final cols = w > 900 ? 3 : w > 600 ? 2 : 1;

    return ref.watch(_featuredProvider).when(
      loading: () => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.9,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: cols,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        final items = products.take(3).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _BentoCard(product: items[i], isDark: isDark, index: i),
        );
      },
    );
  }
}

class _BentoCard extends ConsumerStatefulWidget {
  final ProductModel product;
  final bool isDark;
  final int index;
  const _BentoCard({required this.product, required this.isDark, required this.index});

  @override
  ConsumerState<_BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends ConsumerState<_BentoCard> {
  bool _hovered = false;
  bool _addingToCart = false;
  int _imgIndex = 0;
  Timer? _cycleTimer;

  List<String> get _imgs => widget.product.allImageUrls;

  void _startCycling() {
    if (_imgs.length <= 1) return;
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _imgIndex = (_imgIndex + 1) % _imgs.length);
    });
  }

  void _stopCycling() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    if (mounted) setState(() => _imgIndex = 0);
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleBuyNow() async {
    final p = widget.product;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      context.push('/login?redirect=${Uri.encodeComponent('/products/${p.slug}')}');
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await ref.read(cartProvider.notifier).addItem(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${p.name} added to cart'),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final imgs = _imgs;
    final currentUrl = imgs.isNotEmpty ? imgs[_imgIndex] : '';
    final hasImg = currentUrl.isNotEmpty;
    final fallback = ColoredBox(color: widget.isDark ? const Color(0xFF111111) : const Color(0xFFF0F0F0));

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _startCycling();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _stopCycling();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/products/${p.slug}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          transform: _hovered ? (Matrix4.identity()..translate(0.0, -6.0, 0.0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.50)
                  : widget.isDark ? Colors.white.withValues(alpha: 0.07) : AppColors.lightBorder,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 32, offset: const Offset(0, 12))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // ── IMAGE SECTION
              Expanded(
                flex: 62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Crossfade image cycling on hover
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: hasImg
                          ? Image.network(
                              currentUrl,
                              key: ValueKey(currentUrl),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => fallback,
                            )
                          : fallback,
                    ),

                    // Subtle scale on hover (separate from image so switcher works cleanly)
                    if (_hovered)
                      const SizedBox.shrink(),

                    // Vignette — strong at top for text, clear in center to show drone
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.42, 0.70, 1.0],
                            colors: [
                              Colors.black.withValues(alpha: 0.78),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.20),
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Category + Name + CTAs — pinned to top of image
                    Positioned(
                      top: 18,
                      left: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            p.category.replaceAll('_', ' ').toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              height: 1.15,
                              shadows: [Shadow(color: Colors.black, blurRadius: 18)],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _BentoButton(
                                label: 'Learn More',
                                onTap: () => context.push('/products/${p.slug}'),
                              ),
                              const SizedBox(width: 10),
                              _BentoButton(
                                label: _addingToCart ? '...' : 'Buy Now',
                                accent: true,
                                onTap: _addingToCart ? null : _handleBuyNow,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Image counter dots — bottom center, only when multiple images + hovered
                    if (imgs.length > 1 && _hovered)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(imgs.length, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: i == _imgIndex ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == _imgIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )),
                        ),
                      ),
                  ],
                ),
              ),

              // ── INFO SECTION — description + price below image
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                color: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.shortDescription != null && p.shortDescription!.isNotEmpty)
                      Text(
                        p.shortDescription!,
                        style: TextStyle(
                          color: widget.isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          p.formatPrice(p.price),
                          style: TextStyle(
                            color: widget.isDark ? Colors.white : Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (p.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text(
                            p.formatPrice(p.comparePrice!),
                            style: TextStyle(
                              color: widget.isDark ? Colors.white30 : Colors.black26,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              '-${p.discountPercent.toInt()}%',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 80 * widget.index)).fadeIn().slideY(begin: 0.12, curve: Curves.easeOut);
  }
}

class _BentoButton extends StatefulWidget {
  final String label;
  final bool accent;
  final VoidCallback? onTap;
  const _BentoButton({required this.label, this.accent = false, this.onTap});

  @override
  State<_BentoButton> createState() => _BentoButtonState();
}

class _BentoButtonState extends State<_BentoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: widget.accent
              ? AppColors.accent.withValues(alpha: _pressed ? 1.0 : 0.88)
              : Colors.white.withValues(alpha: _pressed ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.accent
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: widget.accent
              ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: widget.accent ? Colors.white : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            shadows: widget.accent ? null : const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

// ─── 3. Video Carousel ────────────────────────────────────────────────────────

class _VideoSection extends StatefulWidget {
  final bool isDark;
  const _VideoSection({required this.isDark});

  @override
  State<_VideoSection> createState() => _VideoSectionState();
}

class _VideoSectionState extends State<_VideoSection> {
  static const List<Map<String, String>> _videos = [
    {'path': 'assets/videos/hero1.mp4', 'label': 'M-Series Motors', 'sub': 'Professional Power Systems'},
    {'path': 'assets/videos/hero2.mp4', 'label': 'Sky-Link Pro', 'sub': 'Long-Range Telemetry'},
    {'path': 'assets/videos/hero3.mp4', 'label': 'DroneHub FC 4 Pro', 'sub': 'Next-Gen Flight Controller'},
  ];

  // Large virtual count for infinite illusion
  static const int _virtualCount = 999999;
  static const int _initialPage = _virtualCount ~/ 2;

  late PageController _pageController;
  int _realIndex = _initialPage % _videos.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.82,
      initialPage: _initialPage,
    );
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_pageController.hasClients) return;
    final virtual = _pageController.page?.round() ?? _initialPage;
    final real = virtual % _videos.length;
    if (real != _realIndex) setState(() => _realIndex = real);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenW = MediaQuery.of(context).size.width;
    final cardSize = screenW * 0.45;

    return Column(
      children: [
        // Section label — centered
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            children: [
              Text(
                'IN ACTION',
                style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3),
              ),
              const SizedBox(height: 8),
              Text(
                'See It Fly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),

        // Carousel + arrow buttons
        Stack(
          children: [
            SizedBox(
              height: cardSize,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _virtualCount,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, virtualIndex) {
                  final realIdx = virtualIndex % _videos.length;
                  final isActive = realIdx == _realIndex;
                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: isActive ? 0 : 24,
                    ),
                    child: _VideoCard(
                      key: ValueKey('video_$realIdx'),
                      videoData: _videos[realIdx],
                      isActive: isActive,
                    ),
                  );
                },
              ),
            ),
            // Left arrow
            Positioned(
              left: 12, top: 0, bottom: 0,
              child: Center(
                child: _VideoNavBtn(
                  icon: Icons.chevron_left_rounded,
                  isDark: isDark,
                  onTap: () {
                    final cur = _pageController.page?.round() ?? _initialPage;
                    _pageController.animateToPage(
                      cur - 1,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
            // Right arrow
            Positioned(
              right: 12, top: 0, bottom: 0,
              child: Center(
                child: _VideoNavBtn(
                  icon: Icons.chevron_right_rounded,
                  isDark: isDark,
                  onTap: () {
                    final cur = _pageController.page?.round() ?? _initialPage;
                    _pageController.animateToPage(
                      cur + 1,
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_videos.length, (i) {
            final active = i == _realIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 28 : 8,
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// Arrow navigation button for video carousel
class _VideoNavBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _VideoNavBtn({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 26, color: Colors.white),
      ),
    );
  }
}

// Single video card
class _VideoCard extends StatefulWidget {
  final Map<String, String> videoData;
  final bool isActive;
  const _VideoCard({super.key, required this.videoData, required this.isActive});

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _ctrl = VideoPlayerController.asset(widget.videoData['path']!)
      ..setLooping(true)
      ..setVolume(0);
    await _ctrl!.initialize();
    if (!mounted) return;
    setState(() => _ready = true);
    if (widget.isActive) _ctrl!.play();
  }

  @override
  void didUpdateWidget(_VideoCard old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      widget.isActive ? _ctrl?.play() : _ctrl?.pause();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          if (_ready && _ctrl != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child: VideoPlayer(_ctrl!),
              ),
            )
          else
            Container(color: const Color(0xFF0A0A0A)),

          // Dim when not active
          if (!widget.isActive)
            Container(color: Colors.black.withValues(alpha: 0.55)),

          // Active: gradient + centered text
          if (widget.isActive) ...[
            // Top gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.65, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),

            // Centered text overlay
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.videoData['sub']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.videoData['label']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VideoLink('Learn More'),
                      const SizedBox(width: 24),
                      _VideoLink('Shop Now'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoLink extends StatelessWidget {
  final String label;
  const _VideoLink(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.white),
      ],
    );
  }
}

// ─── 4. Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final bool isDark;
  const _SectionHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('PROFESSIONAL GRADE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 12)),
          const SizedBox(height: 8),
          Text('Featured Components', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
        ],
      ),
    );
  }
}

// ─── 5. Products Grid ─────────────────────────────────────────────────────────

class _ProductsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final cols = w > 1200 ? 4 : w > 800 ? 3 : 2;
    const pad = EdgeInsets.symmetric(horizontal: 16);

    return ref.watch(_featuredProvider).when(
      loading: () => SliverPadding(
        padding: pad,
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.62, crossAxisSpacing: 12, mainAxisSpacing: 12),
          delegate: SliverChildBuilderDelegate((_, __) => const ProductCardShimmer(), childCount: 6),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (products) => products.isEmpty
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : SliverPadding(
              padding: pad,
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.62, crossAxisSpacing: 12, mainAxisSpacing: 12),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ProductCard(product: products[i], index: i)
                      .animate().fadeIn(delay: Duration(milliseconds: 60 * i)).slideY(begin: 0.12),
                  childCount: products.length,
                ),
              ),
            ),
    );
  }
}
