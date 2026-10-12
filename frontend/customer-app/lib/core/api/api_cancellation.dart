import 'package:dio/dio.dart';

/// Handle hủy request độc lập với thư viện HTTP ở presentation.
class ApiCancellation {
  final CancelToken transportToken = CancelToken();
  bool get isCancelled => transportToken.isCancelled;
  void cancel([Object? reason]) => transportToken.cancel(reason);
}
