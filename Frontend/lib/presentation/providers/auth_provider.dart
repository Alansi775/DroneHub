import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
  AuthState copyWith({UserModel? user, bool? isLoading, String? error, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  // clientId is required for Flutter Web — replace with your actual Google Client ID
  static const _kGoogleClientId = '704004803805-n4ljlc85kqj5fhl96ohgtvbsnlvbi83d.apps.googleusercontent.com';

  final GoogleSignIn _google = GoogleSignIn(
    clientId: _kGoogleClientId,
    scopes: ['email', 'profile'],
  );

  AuthNotifier(this._repo) : super(const AuthState()) {
    _loadStoredUser();
  }

  Future<void> _loadStoredUser() async {
    state = state.copyWith(isLoading: true);
    final user = await _repo.getStoredUser();
    state = AuthState(user: user);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(email, password);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.register(name, email, password);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> googleSignIn() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await _google.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      final auth = await account.authentication;
      if (auth.idToken == null) {
        state = state.copyWith(isLoading: false, error: 'Google auth failed');
        return false;
      }
      final user = await _repo.googleLogin(auth.idToken!);
      state = AuthState(user: user);
      return true;
    } catch (e) {
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

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('401')) return 'Invalid email or password';
    if (msg.contains('409')) return 'Email already registered';
    if (msg.contains('SocketException') || msg.contains('Connection')) return 'No internet connection';
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
