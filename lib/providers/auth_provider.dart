import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  User? get user => _user;
  int get dailyCheckInStreak => _user?.dailyCheckInStreak ?? 0;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    _user = await _authService.getCurrentUser();
    if (_user != null) {
      await registerDailyCheckIn();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.login(email, password);
      _user = result;
      if (_user != null) {
        await registerDailyCheckIn();
      }
      _isLoading = false;
      notifyListeners();
      return result != null ? null : 'Invalid credentials';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.signInWithGoogle();
      _user = result;
      if (_user != null) {
        await registerDailyCheckIn();
      }
      _isLoading = false;
      notifyListeners();
      return result != null ? null : 'Google sign-in cancelled';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> signUp(String name, String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.signUp(name, username, email, password);
      _user = result;
      if (_user != null) {
        await registerDailyCheckIn();
      }
      _isLoading = false;
      notifyListeners();
      return result != null ? null : 'Failed to sign up';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    notifyListeners();
    final success = await _authService.requestPasswordReset(email);
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<List<User>> searchUsers(String query) async {
    return await _authService.searchUser(query);
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> updateProfile(String name, String email, String? profileImageUrl) async {
    if (_user == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    final updatedUser = User(
      id: _user!.id,
      name: name,
      username: _user!.username,
      email: email,
      profileImageUrl: profileImageUrl ?? _user!.profileImageUrl,
    );
    
    _user = await _authService.updateProfile(updatedUser);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> registerDailyCheckIn() async {
    if (_user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentLastCheckIn = _user!.lastCheckIn;
    final lastCheckInDate = currentLastCheckIn == null
        ? null
        : DateTime(currentLastCheckIn.year, currentLastCheckIn.month, currentLastCheckIn.day);

    if (lastCheckInDate == today) return;

    final yesterday = today.subtract(const Duration(days: 1));
    final newStreak = lastCheckInDate == yesterday
        ? (_user!.dailyCheckInStreak + 1)
        : 1;

    final checkedInUser = User(
      id: _user!.id,
      name: _user!.name,
      username: _user!.username,
      email: _user!.email,
      profileImageUrl: _user!.profileImageUrl,
      dailyCheckInStreak: newStreak,
      lastCheckIn: today,
    );

    _user = await _authService.updateProfile(checkedInUser);
    notifyListeners();
  }

  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    notifyListeners();
    final success = await _authService.updatePassword(currentPassword, newPassword);
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    final success = await _authService.deleteAccount();
    if (success) {
      _user = null;
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }
}
