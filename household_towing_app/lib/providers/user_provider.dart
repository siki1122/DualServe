import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _providerProfile;
  bool _isLoading = false;
  String? _role;
  bool _isDarkMode = false;
  String? _errorMessage;

  UserProvider() {
    _loadTheme();
  }

  Map<String, dynamic>? get userProfile => _userProfile;
  Map<String, dynamic>? get providerProfile => _providerProfile;
  bool get isLoading => _isLoading;
  String? get role => _role;
  bool get isDarkMode => _isDarkMode;
  String? get errorMessage => _errorMessage;

  bool get isProvider => _role?.toLowerCase() == 'provider';
  bool get isAdmin => _role?.toLowerCase() == 'admin';
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? "";

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  /// Load current user profile and role
  Future<void> loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _userProfile = null;
      _providerProfile = null;
      _role = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _errorMessage = null;
      // Get role and base profile from 'users'
      final profile = await _userService.getUserProfile(user.uid);
      if (profile != null) {
        _userProfile = profile;
        _role = profile['role'];

        // If provider, also fetch provider-specific data
        if (_role == 'provider') {
          _providerProfile = await _userService.getProviderProfile(user.uid);
        }
      } else {
        _errorMessage = "User profile not found";
      }
    } catch (e) {
      _errorMessage = "Failed to load user data: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update availability (optimistic UI update)
  Future<void> toggleAvailability(bool value) async {
    if (_providerProfile == null) return;

    final previousValue = _providerProfile!['isAvailable'] ?? true;
    _providerProfile!['isAvailable'] = value;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _userService.updateProviderAvailability(user.uid, value);
      }
    } catch (e) {
      // Revert on error
      _providerProfile!['isAvailable'] = previousValue;
      notifyListeners();
      rethrow;
    }
  }

  /// Clear data on logout
  void clear() {
    _userProfile = null;
    _providerProfile = null;
    _role = null;
    notifyListeners();
  }
}
