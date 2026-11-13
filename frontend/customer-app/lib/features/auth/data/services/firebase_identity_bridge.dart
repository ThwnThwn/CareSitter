import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/firebase_identity_bridge.dart';
import '../../domain/google_identity_gateway.dart';

final firebaseIdentityBridgeProvider = Provider<FirebaseIdentityBridge>(
  (_) => FirebaseGoogleIdentityBridge(),
);

class FirebaseGoogleIdentityBridge implements FirebaseIdentityBridge {
  static const _ownerKey = 'firebase_google_owner';
  static const _uidKey = 'firebase_google_uid';
  final _storage = const FlutterSecureStorage();
  Future<void> _tail = Future.value();
  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<FirebaseAuth> _auth() async {
    if (Firebase.apps.every((app) => app.name != '[DEFAULT]')) {
      await Firebase.initializeApp();
    }
    return FirebaseAuth.instance;
  }

  @override
  Future<String?> exchangeGoogleToken(String googleIdToken) =>
      _serialize(() => _exchange(googleIdToken));
  Future<String?> _exchange(String googleIdToken) async {
    if (kIsWeb) return null;
    try {
      final auth = await _auth();
      final result = await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleIdToken),
      );
      final token = await result.user?.getIdToken(true);
      if (token == null || token.isEmpty) throw StateError('missing token');
      return token;
    } on FirebaseAuthException {
      throw const GoogleIdentityException(
        GoogleIdentityFailureCode.unknown,
        'Không thể xác thực Firebase. Vui lòng thử lại.',
      );
    } catch (_) {
      throw const GoogleIdentityException(
        GoogleIdentityFailureCode.unknown,
        'Không thể xác thực Firebase. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<void> bindOwner(String ownerId) => _serialize(() => _bind(ownerId));
  Future<void> _bind(String ownerId) async {
    if (kIsWeb) return;
    final uid = (await _auth()).currentUser?.uid;
    if (uid == null) throw StateError('Firebase session missing');
    await _storage.write(key: _ownerKey, value: ownerId);
    await _storage.write(key: _uidKey, value: uid);
  }

  @override
  Future<bool> reconcileSession(String? ownerId) =>
      _serialize(() => _reconcile(ownerId));
  Future<bool> _reconcile(String? ownerId) async {
    if (kIsWeb) return true;
    final expectedOwner = await _storage.read(key: _ownerKey);
    if (expectedOwner == null) {
      // An abandoned Firebase login must not remain after backend failure/restart.
      await _signOut();
      return true;
    }
    final uid = await _storage.read(key: _uidKey);
    if (ownerId == expectedOwner &&
        uid != null &&
        (await _auth()).currentUser?.uid == uid) {
      return true;
    }
    await _signOut();
    return false;
  }

  @override
  Future<void> signOut() => _serialize(_signOut);
  Future<void> _signOut() async {
    try {
      if (!kIsWeb && Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
        await FirebaseAuth.instance.signOut();
      }
    } finally {
      await _storage.delete(key: _ownerKey);
      await _storage.delete(key: _uidKey);
    }
  }
}
