import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/failures.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Centralized authentication authority backed by Supabase Auth and protected `user_roles` database table.
class AppAuthProvider extends ChangeNotifier {
  final SupabaseClient? _injected;
  SupabaseClient get _supabase => _injected ?? Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  AuthStatus _status = AuthStatus.unknown;
  User? _currentUser;
  String? _currentRole;
  bool _isEmailVerified = false;
  String? _errorMessage;
  bool _isLoading = false;

  AppAuthProvider({SupabaseClient? client}) : _injected = client {
    try {
      _initializeAuth();
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
  }

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUnknown => _status == AuthStatus.unknown;
  User? get currentUser => _currentUser;
  String? get currentRole => _currentRole;
  bool get isEmailVerified => _isEmailVerified;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  /// Initializes authentication listener and restores active session.
  void _initializeAuth() {
    try {
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        _currentUser = currentSession.user;
        _isEmailVerified = currentSession.user.emailConfirmedAt != null;
        _checkDeactivationStatus(currentSession.user.id).then((isDeactivated) {
          if (!isDeactivated) {
            _status = AuthStatus.authenticated;
            _fetchRoleFromDatabase(currentSession.user.id).then((_) {
              notifyListeners();
            });
          }
        });
      } else {
        _status = AuthStatus.unauthenticated;
      }

      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null) {
          final isDeactivated = await _checkDeactivationStatus(session.user.id);
          if (isDeactivated) return;
          _currentUser = session.user;
          _isEmailVerified = session.user.emailConfirmedAt != null;
          await _fetchRoleFromDatabase(session.user.id);
          _status = AuthStatus.authenticated;
        } else {
          _currentUser = null;
          _currentRole = null;
          _isEmailVerified = false;
          _status = AuthStatus.unauthenticated;
        }
        notifyListeners();
      });
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
  }

  /// Verifies account active status against `profiles.is_deactivated`.
  /// If soft-deactivated, immediately revokes active session and records explanatory error.
  Future<bool> _checkDeactivationStatus(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('is_deactivated')
          .eq('id', userId)
          .maybeSingle();

      if (res != null && res['is_deactivated'] == true) {
        _errorMessage = 'Your account has been deactivated. Please contact customer support.';
        await signOut();
        return true;
      }
    } catch (e) {
      debugPrint('Error checking deactivation status: $e');
    }
    return false;
  }

  /// Loads canonical role strictly from protected `public.user_roles` database table.
  /// Does NOT trust client metadata or appMetadata fallback.
  Future<void> _fetchRoleFromDatabase(String userId) async {
    try {
      final res = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null && res['role'] != null) {
        _currentRole = res['role'] as String;
      } else {
        _currentRole = 'buyer'; // default fallback for unassigned accounts
      }
    } catch (e) {
      debugPrint('Error fetching role for user $userId: $e');
      _currentRole = 'buyer';
    }
  }

  /// Refreshes user role directly from `user_roles` table on demand.
  Future<String?> refreshUserRole() async {
    if (_currentUser == null) return null;
    await _fetchRoleFromDatabase(_currentUser!.id);
    notifyListeners();
    return _currentRole;
  }

  /// Canonical login strictly against Supabase Auth endpoint.
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthenticationFailure(message: 'Authentication failed. Please check your credentials.');
      }

      final isDeactivated = await _checkDeactivationStatus(user.id);
      if (isDeactivated) {
        throw const AuthenticationFailure(message: 'Your account has been deactivated. Please contact customer support.');
      }

      _currentUser = user;
      _isEmailVerified = user.emailConfirmedAt != null;
      await _fetchRoleFromDatabase(user.id);
      _status = AuthStatus.authenticated;

      _isLoading = false;
      notifyListeners();
      return _currentRole;
    } catch (e) {
      _isLoading = false;
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
      _currentRole = null;
      
      const failure = AuthenticationFailure(message: 'Invalid email address or password.');
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  /// Signs up a new user via Supabase Auth.
  Future<User?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName},
      );

      _isLoading = false;
      notifyListeners();
      return response.user;
    } catch (e, st) {
      _isLoading = false;
      final failure = FailureMapper.mapException(e, st);
      _errorMessage = failure.message;
      notifyListeners();
      throw failure;
    }
  }

  /// Requests password reset email via Supabase Auth.
  /// Safe output does not reveal whether the email exists in the database.
  Future<bool> resetPasswordForEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      // Always return true to caller to prevent account enumeration
      return true;
    }
  }

  /// Signs out current session and resets auth state.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Ignore signout network errors; local state must be cleared regardless
    } finally {
      _currentUser = null;
      _currentRole = null;
      _isEmailVerified = false;
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
