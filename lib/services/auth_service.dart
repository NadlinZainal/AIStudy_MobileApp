import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import 'firestore_service.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        // Check if user exists in Firestore, if not create them
        final existingUser = await FirestoreService.instance.getUserById(userCredential.user!.uid);
        if (existingUser != null) return existingUser;

        final newUser = User(
          id: userCredential.user!.uid,
          name: googleUser.displayName ?? 'Google User',
          username: googleUser.email.split('@')[0],
          email: googleUser.email,
        );

        await FirestoreService.instance.upsertUser(newUser);
        return newUser;
      }
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    }
    return null;
  }

  Future<User?> signUp(String name, String username, String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final newUser = User(
          id: userCredential.user!.uid,
          name: name,
          username: username,
          email: email,
        );

        await FirestoreService.instance.upsertUser(newUser);
        return newUser;
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('SignUp Error: $e');
      rethrow;
    }
    return null;
  }

  Future<User?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return await FirestoreService.instance.getUserById(userCredential.user!.uid);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Login Error: $e');
      rethrow;
    }
    return null;
  }

  Future<User?> updateProfile(User updatedUser) async {
    await FirestoreService.instance.upsertUser(updatedUser);
    return updatedUser;
  }

  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Technically we should re-authenticate the user first before updating the password
        // if they've been logged in for a while. For simplicity, we just try to update.
        firebase_auth.AuthCredential credential = firebase_auth.EmailAuthProvider.credential(
          email: user.email!, 
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);
        return true;
      }
    } catch (e) {
      debugPrint('Update Password Error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<bool> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      debugPrint('Reset Password Error: $e');
      return false;
    }
  }

  Future<User?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      final user = await FirestoreService.instance.getUserById(firebaseUser.uid);
      if (user != null) return user;
    }
    return null;
  }

  Future<List<User>> searchUser(String query) async {
    return await FirestoreService.instance.searchUsers(query);
  }

  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final uid = user.uid;
        // Delete Firestore data first
        await FirestoreService.instance.deleteUser(uid);
        // Delete Firebase Auth user
        await user.delete();
        return true;
      }
    } catch (e) {
      debugPrint('Delete Account Error: $e');
    }
    return false;
  }
}

