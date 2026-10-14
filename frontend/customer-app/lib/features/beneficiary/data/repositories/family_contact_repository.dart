import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/family_contact_model.dart';

final familyContactRepositoryProvider = Provider<FamilyContactRepository>(
  (ref) => FamilyContactRepository(ref.read(dioClientProvider)),
);

class FamilyContactRepository {
  final DioClient _dio;

  const FamilyContactRepository(this._dio);

  Future<List<FamilyContactModel>> getContacts(
      {ApiCancellation? cancellation}) async {
    final response = cancellation == null
        ? await _dio.get<List<dynamic>>(ApiPaths.familyContacts)
        : await _dio.getCancelable<List<dynamic>>(ApiPaths.familyContacts,
            cancelToken: cancellation.transportToken);
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FamilyContactModel.fromJson)
        .toList();
  }

  Future<FamilyContactModel> createContact({
    required String fullName,
    required String phoneNumber,
    ApiCancellation? cancellation,
  }) async {
    final data = {'fullName': fullName, 'phoneNumber': phoneNumber};
    final response = cancellation == null
        ? await _dio.post<Map<String, dynamic>>(
            ApiPaths.familyContacts,
            data: data,
          )
        : await _dio.postCancelable<Map<String, dynamic>>(ApiPaths.familyContacts,
            data: data, cancelToken: cancellation.transportToken);
    return FamilyContactModel.fromJson(response.data ?? const {});
  }
}
