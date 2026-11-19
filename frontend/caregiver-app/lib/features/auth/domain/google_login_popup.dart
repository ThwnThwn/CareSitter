abstract interface class GoogleLoginPopup {
  Future<String> requestIdToken();
  void dispose();
}
