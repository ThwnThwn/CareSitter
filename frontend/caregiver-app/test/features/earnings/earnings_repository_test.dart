import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/features/earnings/data/models/wallet_activity.dart';
import 'package:caregiver_app/features/earnings/data/repositories/earnings_repository.dart';

class _Http implements DioClient {
  final payloads = <Map<String, dynamic>>[];
  final reads = <(String, Map<String, dynamic>?)>[];

  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? query, CancelToken? cancelToken}) async {
    reads.add((path, query));
    final payout = path == '/payments/payouts';
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{
        'items': [
          if (payout)
            {
              'amount': 120000,
              'status': 'PENDING',
              'bankName': 'Test Bank',
              'requestedAt': '2026-11-19T08:00:00Z',
            }
          else
            {
              'transactionType': 'CAREGIVER_EARNING',
              'amount': 0,
              'direction': 'CREDIT',
              'status': 'POSTED',
              'createdAt': '2026-11-19T08:00:00Z',
            },
        ],
        'total': 35,
      } as T,
    );
  }

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
  test('history uses the wallet and payout sources and keeps reported zero',
      () async {
    final http = _Http();
    final repository = EarningsRepository(http);
    final wallet =
        await repository.loadActivity(WalletActivityKind.transactions, 1);
    final payouts =
        await repository.loadActivity(WalletActivityKind.payouts, 2);
    expect(http.reads.map((read) => read.$1),
        ['/wallet/transactions', '/payments/payouts']);
    expect(http.reads.last.$2, {'page': 2, 'pageSize': 20});
    expect(wallet.items.single.amount, 0);
    expect(wallet.items.single.isCredit, isTrue);
    expect(wallet.hasMore, isTrue);
    expect(payouts.items.single.status, 'PENDING');
    expect(payouts.items.single.bankName, 'Test Bank');
    expect(payouts.hasMore, isFalse);
  });

  test('payout requests preserve the supplied key and the existing API payload',
      () async {
    final http = _Http();
    final repository = EarningsRepository(http);
    for (var attempt = 0; attempt < 2; attempt++) {
      await repository.requestWithdrawal(
          amount: 123456,
          bankName: 'Test Bank',
          bankBin: '970436',
          accountHolderName: 'Test User',
          accountNumber: '000000',
          idempotencyKey: 'same-operation');
    }
    expect(http.payloads.first, {
      'amount': 123456,
      'bankName': 'Test Bank',
      'bankBin': '970436',
      'accountHolderName': 'Test User',
      'accountNumber': '000000',
      'idempotencyKey': 'same-operation',
    });
    expect(http.payloads.last, http.payloads.first);
  });
}
