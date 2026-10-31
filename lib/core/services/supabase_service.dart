import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/failures.dart';

class SupabaseService extends ChangeNotifier {
  final SupabaseClient? _injected;
  SupabaseClient get _supabase => _injected ?? Supabase.instance.client;
  
  bool _isLoading = false;
  String? _userRole;

  SupabaseService({SupabaseClient? client}) : _injected = client;

  bool get isLoading => _isLoading;
  String? get userRole => _userRole;
  User? get currentUser => _supabase.auth.currentUser;

  // 1. Email Password Login
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final data = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .single();

        _userRole = data['role'] as String?;
        _isLoading = false;
        notifyListeners();
        return _userRole;
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e, st) {
      _isLoading = false;
      notifyListeners();
      throw FailureMapper.mapException(e, st);
    }
  }

  // 2. Email Password Sign Up
  Future<User?> signUp(String email, String password, {String role = 'buyer'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': role},
      );

      _isLoading = false;
      notifyListeners();
      return response.user;
    } catch (e, st) {
      _isLoading = false;
      notifyListeners();
      throw FailureMapper.mapException(e, st);
    }
  }

  // 3. Logout
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      _userRole = null;
      notifyListeners();
    } catch (e, st) {
      throw FailureMapper.mapException(e, st);
    }
  }
}
