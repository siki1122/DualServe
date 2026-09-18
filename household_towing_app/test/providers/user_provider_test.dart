import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:household_towing_app/providers/user_provider.dart';
import 'package:household_towing_app/services/user_service.dart';

// 1. Create Mock classes using Mockito
class MockUserService extends Mock implements UserService {
  // Since you are using mockito without build_runner generation for this file,
  // we can use mockito's fallback or manual overrides for methods we test.
  @override
  Future<Map<String, dynamic>?> getUserProfile(String uid) {
    return super.noSuchMethod(
      Invocation.method(#getUserProfile, [uid]),
      returnValue: Future.value({'name': 'John Doe', 'role': 'provider'}),
    );
  }

  @override
  Future<Map<String, dynamic>?> getProviderProfile(String uid) {
    return super.noSuchMethod(
      Invocation.method(#getProviderProfile, [uid]),
      returnValue: Future.value({'companyName': 'John Towing', 'isAvailable': true}),
    );
  }

  @override
  Future<Map<String, dynamic>?> getDriverProfile(String uid) {
    return super.noSuchMethod(
      Invocation.method(#getDriverProfile, [uid]),
      returnValue: Future.value({'vehicle': 'Tow Truck 1', 'rating': 4.8}),
    );
  }

  @override
  Future<void> updateProviderAvailability(String uid, bool isAvailable) {
    return super.noSuchMethod(
      Invocation.method(#updateProviderAvailability, [uid, isAvailable]),
      returnValue: Future.value(),
    );
  }
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  User? get currentUser {
    return super.noSuchMethod(
      Invocation.getter(#currentUser),
      returnValue: MockUser(),
    );
  }
}

class MockUser extends Mock implements User {
  @override
  String get uid => '12345';
}

void main() {
  late UserProvider userProvider;
  late MockUserService mockUserService;
  late MockFirebaseAuth mockFirebaseAuth;

  setUp(() {
    // Mock shared preferences for the theme loader
    SharedPreferences.setMockInitialValues({});
    
    mockUserService = MockUserService();
    mockFirebaseAuth = MockFirebaseAuth();

    // Inject mocks into the provider
    userProvider = UserProvider(
      userService: mockUserService,
      firebaseAuth: mockFirebaseAuth,
    );
  });

  group('UserProvider White-Box Tests (Mockito) -', () {
    
    test('loadCurrentUserData clears data if user is null', () async {
      // Arrange: Force currentUser to return null for this specific test
      when(mockFirebaseAuth.currentUser).thenReturn(null);

      // Act
      await userProvider.loadCurrentUserData();

      // Assert
      expect(userProvider.userProfile, isNull);
      expect(userProvider.role, isNull);
      expect(userProvider.isLoading, isFalse);
      
      // Verify the database was never called
      verifyNever(mockUserService.getUserProfile('12345'));
    });

    test('loadCurrentUserData fetches provider profile when role is provider', () async {
      // Arrange
      final fakeUser = MockUser();
      when(mockFirebaseAuth.currentUser).thenReturn(fakeUser);
      
      // Stub the database responses
      when(mockUserService.getUserProfile('12345')).thenAnswer(
        (_) async => {'name': 'John Doe', 'role': 'provider'},
      );
      
      when(mockUserService.getProviderProfile('12345')).thenAnswer(
        (_) async => {'companyName': 'John Towing', 'isAvailable': true},
      );

      // Act
      await userProvider.loadCurrentUserData();

      // Assert
      expect(userProvider.role, 'provider');
      expect(userProvider.isProvider, isTrue);
      expect(userProvider.userProfile?['name'], 'John Doe');
      expect(userProvider.providerProfile?['companyName'], 'John Towing');
      expect(userProvider.isLoading, isFalse);

      // Verify the correct branches were executed
      verify(mockUserService.getUserProfile('12345')).called(1);
      verify(mockUserService.getProviderProfile('12345')).called(1);
    });
    test('loadCurrentUserData fetches driver profile when role is driver', () async {
      final fakeUser = MockUser();
      when(mockFirebaseAuth.currentUser).thenReturn(fakeUser);
      
      when(mockUserService.getUserProfile('12345')).thenAnswer(
        (_) async => {'name': 'Alice Driver', 'role': 'driver'},
      );
      
      when(mockUserService.getDriverProfile('12345')).thenAnswer(
        (_) async => {'vehicle': 'Tow Truck A'},
      );

      await userProvider.loadCurrentUserData();

      expect(userProvider.role, 'driver');
      expect(userProvider.isDriver, isTrue);
      expect(userProvider.driverProfile?['vehicle'], 'Tow Truck A');
      
      verify(mockUserService.getUserProfile('12345')).called(1);
      verify(mockUserService.getDriverProfile('12345')).called(1);
      verifyNever(mockUserService.getProviderProfile('12345'));
    });

    test('toggleAvailability updates optimistic UI and calls backend', () async {
      // Setup provider first
      final fakeUser = MockUser();
      when(mockFirebaseAuth.currentUser).thenReturn(fakeUser);
      when(mockUserService.getUserProfile('12345')).thenAnswer(
        (_) async => {'name': 'John Doe', 'role': 'provider'},
      );
      when(mockUserService.getProviderProfile('12345')).thenAnswer(
        (_) async => {'companyName': 'John Towing', 'isAvailable': true},
      );
      await userProvider.loadCurrentUserData();
      
      // Now test toggle
      when(mockUserService.updateProviderAvailability('12345', false)).thenAnswer((_) async => {});
      
      await userProvider.toggleAvailability(false);
      
      expect(userProvider.providerProfile?['isAvailable'], false);
      verify(mockUserService.updateProviderAvailability('12345', false)).called(1);
    });

    test('toggleTheme switches between dark and light mode', () async {
      expect(userProvider.isDarkMode, isFalse);
      
      await userProvider.toggleTheme();
      expect(userProvider.isDarkMode, isTrue);

      await userProvider.toggleTheme();
      expect(userProvider.isDarkMode, isFalse);
    });

    test('clear resets all state variables', () async {
      // First populate it
      final fakeUser = MockUser();
      when(mockFirebaseAuth.currentUser).thenReturn(fakeUser);
      when(mockUserService.getUserProfile('12345')).thenAnswer(
        (_) async => {'name': 'John', 'role': 'provider'}
      );
      when(mockUserService.getProviderProfile('12345')).thenAnswer(
        (_) async => {'companyName': 'John Towing'}
      );
      await userProvider.loadCurrentUserData();
      
      // Ensure populated
      expect(userProvider.role, 'provider');
      expect(userProvider.userProfile, isNotNull);
      
      // Act
      userProvider.clear();
      
      // Assert
      expect(userProvider.role, isNull);
      expect(userProvider.userProfile, isNull);
      expect(userProvider.providerProfile, isNull);
      expect(userProvider.driverProfile, isNull);
      expect(userProvider.isLoading, isTrue);
    });
  });
}
