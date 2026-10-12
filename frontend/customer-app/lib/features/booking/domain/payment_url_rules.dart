Uri? validPaymentUrl(String url, String provider) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (provider == 'PAYOS' && uri.host != 'pay.payos.vn')) {
    return null;
  }
  return uri;
}
