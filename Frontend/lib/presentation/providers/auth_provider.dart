import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool needsOnboarding;
  final bool awaitingVerification;
  final String? verificationEmail;
  final String? pendingRedirect;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.needsOnboarding = false,
    this.awaitingVerification = false,
    this.verificationEmail,
    this.pendingRedirect,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? needsOnboarding,
    bool? awaitingVerification,
    String? verificationEmail,
    String? pendingRedirect,
    bool clearUser = false,
    bool clearPendingRedirect = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: error,
        needsOnboarding: needsOnboarding ?? this.needsOnboarding,
        awaitingVerification: awaitingVerification ?? this.awaitingVerification,
        verificationEmail: verificationEmail ?? this.verificationEmail,
        pendingRedirect: clearPendingRedirect ? null : (pendingRedirect ?? this.pendingRedirect),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  static const _kGoogleClientId = '704004803805-n4ljlc85kqj5fhl96ohgtvbsnlvbi83d.apps.googleusercontent.com';

  final GoogleSignIn _google = GoogleSignIn(
    clientId: _kGoogleClientId,
    scopes: ['email', 'profile'],
  );

  AuthNotifier(this._repo) : super(const AuthState(isLoading: true)) {
    _loadStoredUser();
  }

  Future<void> _loadStoredUser() async {
    state = state.copyWith(isLoading: true);
    final user = await _repo.getStoredUser();
    state = AuthState(user: user);
  }

  Future<bool> login(String email, String password, {String? redirectAfter}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(email, password);
      state = AuthState(
        user: user,
        needsOnboarding: !user.hasCompleteAddress && !user.isAdmin,
        pendingRedirect: redirectAfter,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  /// Returns true when user is logged in, false when email verification is pending.
  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.register(name, email, password);
      if (user == null) {
        // Backend sent verification email — no JWT yet
        state = AuthState(awaitingVerification: true, verificationEmail: email);
        return false;
      }
      state = AuthState(user: user, needsOnboarding: !user.isAdmin);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> googleSignIn({String? redirectAfter}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await _google.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      debugPrint('[Google] idToken: ${idToken != null ? "present" : "null"}');
      debugPrint('[Google] accessToken: ${accessToken != null ? "present" : "null"}');

      if (idToken == null && accessToken == null) {
        state = state.copyWith(isLoading: false, error: 'Google auth failed: no token returned');
        return false;
      }

      final user = await _repo.googleLogin(idToken: idToken, accessToken: accessToken);
      state = AuthState(
        user: user,
        needsOnboarding: !user.hasCompleteAddress && !user.isAdmin,
        pendingRedirect: redirectAfter,
      );
      return true;
    } catch (e) {
      debugPrint('[Google] error: $e');
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    try { await _google.signOut(); } catch (_) {}
    state = const AuthState();
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  void completeOnboarding() {
    state = state.copyWith(needsOnboarding: false); // pendingRedirect preserved
  }

  void clearPendingRedirect() {
    state = state.copyWith(clearPendingRedirect: true);
  }

  void clearAwaitingVerification() {
    state = const AuthState();
  }

  String _parseError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) return 'Invalid email or password';
      if (code == 409) {
        final serverMsg = e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString()
            : null;
        return serverMsg ?? 'Email already registered';
      }
      final serverMsg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      if (serverMsg != null) return serverMsg;
      return 'Server error (${code ?? e.type.name})';
    }
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) return 'No internet connection';
    return kDebugMode ? msg : 'Something went wrong. Please try again.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});