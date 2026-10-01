class GoogleIdentityCredential {
  const GoogleIdentityCredential({required this.idToken});

  final String idToken;
}

enum GoogleIdentityFailureCode {
  cancelled,
  configuration,
  missingIdToken,
  unsupportedPlatform,
  unknown,
}

class GoogleIdentityException implements Exception {
  const GoogleIdentityException(this.code, this.message);

  final GoogleIdentityFailureCode code;
  final String message;

  @override
  String toString() => message;
}

abstract interface class GoogleIdentityGateway {
  Stream<GoogleIdentityCredential> get credentials;

  Future<void> initialize();

  Future<void> authenticate();

  Future<void> clearLocalSelection();
}
