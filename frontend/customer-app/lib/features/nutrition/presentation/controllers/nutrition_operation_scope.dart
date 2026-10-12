import 'package:caresitter_customer/core/api/api_cancellation.dart';

class NutritionOperationScope {
  ApiCancellation token = ApiCancellation();
  int generation = 0;
  bool _closed = false;
  bool current(int value) => !_closed && generation == value;
  void cancel() {
    generation++;
    token.cancel();
    if (!_closed) token = ApiCancellation();
  }

  void dispose() {
    _closed = true;
    cancel();
  }
}
