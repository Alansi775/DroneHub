import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/products/products_screen.dart';
import '../../presentation/screens/products/product_detail_screen.dart';
import '../../presentation/screens/cart/cart_screen.dart';
import '../../presentation/screens/checkout/checkout_screen.dart';
import '../../presentation/screens/checkout/order_success_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/orders/orders_screen.dart';
import '../../presentation/screens/orders/order_detail_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/admin/admin_products_screen.dart';
import '../../presentation/screens/admin/admin_orders_screen.dart';
import '../../presentation/screens/admin/admin_add_product_screen.dart';
import '../../presentation/screens/main_shell.dart';
import '../../presentation/providers/auth_provider.dart';

// Keys are created once — never recreated
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// ChangeNotifier that mirrors AuthState — used as router refreshListenable
/// so GoRouter refreshes on auth changes without rebuilding itself.
class _AuthNotifierBridge extends ChangeNotifier {
  _AuthNotifierBridge(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final bridge = _AuthNotifierBridge(ref);
  ref.onDispose(bridge.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: bridge,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.user != null;
      final isAdmin = authState.user?.role == 'admin';
      final path = state.uri.path;

      final authRoutes = ['/login', '/register'];
      final protectedRoutes = ['/profile', '/orders', '/checkout'];
      final adminRoutes = ['/admin'];

      if (authRoutes.contains(path) && isLoggedIn) return '/';
      if (protectedRoutes.any((r) => path.startsWith(r)) && !isLoggedIn) {
        return '/login?redirect=${Uri.encodeComponent(path)}';
      }
      if (adminRoutes.any((r) => path.startsWith(r)) && (!isLoggedIn || !isAdmin)) {
        return '/';
      }
      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
          GoRoute(
            path: '/products',
            builder: (c, s) => ProductsScreen(
              category: s.uri.queryParameters['category'],
              search: s.uri.queryParameters['search'],
            ),
          ),
          GoRoute(path: '/products/:slug', builder: (c, s) => ProductDetailScreen(slug: s.pathParameters['slug']!)),
          GoRoute(path: '/cart', builder: (c, s) => const CartScreen()),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
          GoRoute(path: '/orders/:id', builder: (c, s) => OrderDetailScreen(orderId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: '/checkout', builder: (c, s) => const CheckoutScreen()),
      GoRoute(
        path: '/order-success/:orderId',
        builder: (c, s) => OrderSuccessScreen(orderId: s.pathParameters['orderId']!),
      ),
      GoRoute(path: '/login', builder: (c, s) => LoginScreen(redirect: s.uri.queryParameters['redirect'])),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),

      // Admin
      GoRoute(
        path: '/admin',
        builder: (c, s) => const AdminDashboardScreen(),
        routes: [
          GoRoute(path: 'products', builder: (c, s) => const AdminProductsScreen()),
          GoRoute(path: 'products/add', builder: (c, s) => const AdminAddProductScreen()),
          GoRoute(path: 'products/edit/:id', builder: (c, s) => AdminAddProductScreen(productId: s.pathParameters['id'])),
          GoRoute(path: 'orders', builder: (c, s) => const AdminOrdersScreen()),
        ],
      ),
    ],
  );
});
