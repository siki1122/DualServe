import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleAuthService {
  final FirebaseAuth _firebaseAuth;
  late final GoogleSignIn _googleSignIn;

  GoogleAuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn}) 
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    // For mobile only - web uses Firebase Auth directly with signInWithPopup
    if (!kIsWeb) {
      _googleSignIn = googleSignIn ?? GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
      );
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // For web: Use Firebase Auth directly (no gapi needed)
        GoogleAuthProvider googleAuthProvider = GoogleAuthProvider();
        return await _firebaseAuth.signInWithPopup(googleAuthProvider);
      } else {
        // For mobile: Use google_sign_in package
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _firebaseAuth.signInWithCredential(credential);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }
}
