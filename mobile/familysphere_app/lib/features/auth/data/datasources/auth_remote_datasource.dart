import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:familysphere_app/features/auth/data/models/user_model.dart';

/// Remote Data Source - Firebase Operations
/// 
/// This class handles all Firebase Auth and Firestore operations.
/// It's the only place that directly talks to Firebase.
/// 
/// Why separate?
/// - Single place for all Firebase code
/// - Easy to mock for testing
/// - Can be replaced with different backend
class AuthRemoteDataSource {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSource({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Send OTP to phone number
  /// 
  /// Returns verification ID for later verification
  /// Throws exception if sending fails
  Future<String> sendOtp(String phoneNumber) async {
    String? verificationId;
    Exception? error;
    bool codeSentSuccessfully = false;

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        
        // Called when verification is completed automatically (Android)
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          print('✅ Auto-verification completed');
          try {
            await _firebaseAuth.signInWithCredential(credential);
          } catch (e) {
            print('Auto-sign in error (can ignore): $e');
          }
        },
        
        // Called when verification fails
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          // Only set error if code wasn't already sent successfully
          if (!codeSentSuccessfully) {
            print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
            if (e.code == 'invalid-phone-number') {
              error = Exception('Invalid phone number format');
            } else if (e.code == 'too-many-requests') {
              error = Exception('Too many requests. Please try again later');
            } else if (e.code == 'network-request-failed') {
              error = Exception('Network error. Please check your connection');
            } else {
              error = Exception(e.message ?? 'Failed to send OTP. Please try again');
            }
          } else {
            print('⚠️ Verification failed callback fired but code was already sent - ignoring');
          }
        },
        
        // Called when OTP is sent successfully
        codeSent: (String verId, int? resendToken) {
          print('✅ OTP sent successfully. Verification ID: $verId');
          verificationId = verId;
          codeSentSuccessfully = true;
          // Clear any previous errors since code was sent successfully
          error = null;
        },
        
        // Called when auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verId) {
          print('⏱️ Auto-retrieval timeout. Verification ID: $verId');
          if (verificationId == null) {
            verificationId = verId;
            codeSentSuccessfully = true;
          }
        },
      );

      // Wait for callbacks to complete
      await Future.delayed(const Duration(seconds: 3));

      // Check if code was sent successfully (priority over error)
      if (codeSentSuccessfully && verificationId != null) {
        print('✅ Returning verification ID: $verificationId');
        return verificationId!;
      }

      // If we have an error and code wasn't sent, throw it
      if (error != null) {
        print('❌ Throwing error: $error');
        throw error!;
      }

      // No verification ID and no specific error
      throw Exception('Failed to send OTP. Please try again.');
    } catch (e) {
      print('❌ SendOTP Error: $e');
      if (e is Exception) rethrow;
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP code
  /// 
  /// Returns UserModel if verification successful
  /// Throws exception if verification fails
  Future<UserModel> verifyOtp(String verificationId, String otpCode) async {
    try {
      // Create credential
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );

      // Sign in with credential
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw Exception('Authentication failed');
      }

      final firebaseUser = userCredential.user!;

      // Check if user exists in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (userDoc.exists) {
        // Existing user - return from Firestore
        return UserModel.fromFirestore(userDoc);
      } else {
        // New user - create in Firestore
        final newUser = UserModel.create(
          id: firebaseUser.uid,
          phoneNumber: firebaseUser.phoneNumber!,
        );

        await _firestore
            .collection('users')
            .doc(newUser.id)
            .set(newUser.toFirestore());

        return newUser;
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw Exception('Invalid OTP code. Please check and try again.');
      } else if (e.code == 'session-expired') {
        throw Exception('OTP expired. Please request a new code.');
      } else {
        throw Exception(e.message ?? 'Verification failed');
      }
    } catch (e) {
      throw Exception('Verification failed: ${e.toString()}');
    }
  }

  /// Get current user from Firebase and Firestore
  /// 
  /// Returns UserModel if logged in, null otherwise
  Future<UserModel?> getCurrentUser() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      
      if (firebaseUser == null) return null;

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) return null;

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      return null;
    }
  }

  /// Update user profile in Firestore
  /// 
  /// Returns updated UserModel
  Future<UserModel> updateProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (displayName != null) {
        updates['displayName'] = displayName;
      }
      if (photoUrl != null) {
        updates['photoUrl'] = photoUrl;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .update(updates);

      // Get updated user
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Sign in with Google
  /// 
  /// Returns UserModel if sign-in successful
  /// Throws exception if sign-in fails
  Future<UserModel> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In...');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        throw Exception('Google Sign-In canceled');
      }

      print('✅ Google user selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw Exception('Google Sign-In failed');
      }

      final firebaseUser = userCredential.user!;
      print('✅ Firebase sign-in successful: ${firebaseUser.uid}');

      // Check if user exists in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (userDoc.exists) {
        // Existing user - return from Firestore
        print('✅ Existing user found');
        return UserModel.fromFirestore(userDoc);
      } else {
        // New user - create in Firestore
        print('📝 Creating new user in Firestore');
        final newUser = UserModel.create(
          id: firebaseUser.uid,
          phoneNumber: firebaseUser.phoneNumber ?? '',
          displayName: firebaseUser.displayName,
          photoUrl: firebaseUser.photoURL,
        );

        await _firestore
            .collection('users')
            .doc(newUser.id)
            .set(newUser.toFirestore());

        print('✅ New user created');
        return newUser;
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      if (e.toString().contains('canceled')) {
        throw Exception('Sign-in canceled');
      }
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  /// Stream of auth state changes
  /// 
  /// Emits UserModel when user signs in
  /// Emits null when user signs out
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (!userDoc.exists) return null;

        return UserModel.fromFirestore(userDoc);
      } catch (e) {
        return null;
      }
    });
  }
}
