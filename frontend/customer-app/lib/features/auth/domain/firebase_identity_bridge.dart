abstract interface class FirebaseIdentityBridge {
  /// null preserves the existing web OAuth flow; native must return a Firebase token.
  Future<String?> exchangeGoogleToken(String googleIdToken);
  Future<void> bindOwner(String ownerId);
  Future<bool> reconcileSession(String? ownerId);
  Future<void> signOut();
}
