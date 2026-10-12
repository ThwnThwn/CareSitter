import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/features/earnings/data/repositories/earnings_repository.dart';

class _Http implements DioClient {
  final payloads = <Map<String, dynamic>>[];
  @override
  Future<Response<T>> post<T>(String path,
      {dynamic data, CancelToken? cancelToken}) async {
    expect(path, '/payments/payouts');
    payloads.add(Map<String, dynamic>.from(data as Map));
    return Response<T>(
        requestOptions: RequestOptions(path: path), statusCode: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('payout requests preserve the supplied key and the existing API payload',
      () async {
    final http = _Http();
    final repository = EarningsRepository(http);
    for (var attempt = 0; attempt < 2; attempt++) {
      await repository.requestWithdrawal(
          amount: 123456,
          bankName: 'Test Bank',
          accountHolderName: 'Test User',
          accountNumber: '000000',
          idempotencyKey: 'same-operation');
    }
    expect(http.payloads.first, {
      'amount': 123456,
      'bankName': 'Test Bank',
      'accountHolderName': 'Test User',
      'accountNumber': '000000',
      'idempotencyKey': 'same-operation',
    });
    expect(http.payloads.last, http.payloads.first);
  });
}
