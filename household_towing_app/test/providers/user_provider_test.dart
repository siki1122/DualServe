import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_towing_app/providers/user_provider.dart';
import 'package:household_towing_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockUserService extends Mock implements UserService {
  @override
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (uid == 'user_1') {
      return {'name': 'Alice', 'role': 'customer'};
    } else if (uid == 'provider_1') {
      return {'name': 'Bob', 'role': 'provider'};
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getProviderProfile(String uid) async {
    if (uid == 'provider_1') {
      return {'name': 'Bob', 'isAvailable': true};
    }
    return null;
  }

  @override
  Future<void> updateProviderAvailability(String uid, bool isAvailable) async {
    return;
  }
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  final User? _currentUser;
  MockFirebaseAuth(this._currentUser);
  
  @override
  User? get currentUser => _currentUser;
}

class MockUser extends Mock implements User {
  final String _uid;
  MockUser(this._uid);
  
  @override
  String get uid => _uid;
}

void main() {
  group('UserProvider Tests', () {
    late MockUserService mockUserService;

    setUp(() {
      SharedPreferences.setMockInitialValues({'isDarkMode': false});
      mockUserService = MockUserService();
    });

    test('loadCurrentUserData works for customer', () async {
      final mockUser = MockUser('user_1');
      final mockAuth = MockFirebaseAuth(mockUser);
      
      final provider = UserProvider(
        userService: mockUserService,
        firebaseAuth: mockAuth,
      );

      await provider.loadCurrentUserData();
      
      expect(provider.isLoading, false);
      expect(provider.userProfile, isNotNull);
      expect(provider.role, 'customer');
      expect(provider.isProvider, false);
    });

    test('loadCurrentUserData works for provider', () async {
      final mockUser = MockUser('provider_1');
      final mockAuth = MockFirebaseAuth(mockUser);
      
      final provider = UserProvider(
        userService: mockUserService,
        firebaseAuth: mockAuth,
      );

      await provider.loadCurrentUserData();
      
      expect(provider.isLoading, false);
      expect(provider.userProfile, isNotNull);
      expect(provider.role, 'provider');
      expect(provider.isProvider, true);
      expect(provider.providerProfile, isNotNull);
    });

    test('loadCurrentUserData clears data if no user', () async {
      final mockAuth = MockFirebaseAuth(null);
      
      final provider = UserProvider(
        userService: mockUserService,
        firebaseAuth: mockAuth,
      );

      await provider.loadCurrentUserData();
      
      expect(provider.isLoading, false);
      expect(provider.userProfile, isNull);
    });

    test('toggleAvailability updates profile', () async {
      final mockUser = MockUser('provider_1');
      final mockAuth = MockFirebaseAuth(mockUser);
      
      final provider = UserProvider(
        userService: mockUserService,
        firebaseAuth: mockAuth,
      );

      await provider.loadCurrentUserData();
      expect(provider.providerProfile!['isAvailable'], true);

      await provider.toggleAvailability(false);
      expect(provider.providerProfile!['isAvailable'], false);
    });

    test('toggleTheme changes theme', () async {
      final mockAuth = MockFirebaseAuth(null);
      
      final provider = UserProvider(
        userService: mockUserService,
        firebaseAuth: mockAuth,
      );

      expect(provider.isDarkMode, false);
      
      await provider.toggleTheme();
      
      expect(provider.isDarkMode, true);
    });
  });
}
