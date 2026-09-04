import 'package:flutter_test/flutter_test.dart';
import 'package:household_towing_app/services/google_auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  Future<void> signOut() async {
    return super.noSuchMethod(
      Invocation.method(#signOut, []),
      returnValue: Future<void>.value(),
    );
  }
}

class MockGoogleSignIn extends Mock implements GoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signOut() async {
    return super.noSuchMethod(
      Invocation.method(#signOut, []),
      returnValue: Future<GoogleSignInAccount?>.value(null),
    );
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    return super.noSuchMethod(
      Invocation.method(#signIn, []),
      returnValue: Future<GoogleSignInAccount?>.value(null),
    );
  }
}

void main() {
  group('GoogleAuthService Tests', () {
    late GoogleAuthService googleAuthService;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockGoogleSignIn mockGoogleSignIn;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockGoogleSignIn = MockGoogleSignIn();
      googleAuthService = GoogleAuthService(
        firebaseAuth: mockFirebaseAuth,
        googleSignIn: mockGoogleSignIn,
      );
    });

    test('signOut calls both FirebaseAuth and GoogleSignIn signOut', () async {
      when(mockFirebaseAuth.signOut()).thenAnswer((_) async => {});
      when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

      await googleAuthService.signOut();

      verify(mockFirebaseAuth.signOut()).called(1);
      verify(mockGoogleSignIn.signOut()).called(1);
    });

    test('signInWithGoogle handles null user', () async {
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      final result = await googleAuthService.signInWithGoogle();

      expect(result, isNull);
      verify(mockGoogleSignIn.signIn()).called(1);
    });
  });
}
