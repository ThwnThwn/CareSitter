import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/family_contact_model.dart';

final familyContactRepositoryProvider = Provider<FamilyContactRepository>(
  (ref) => FamilyContactRepository(ref.read(dioClientProvider)),
);

class FamilyContactRepository {
  final DioClient _dio;

  const FamilyContactRepository(this._dio);

  Future<List<FamilyContactModel>> getContacts() async {
    final response = await _dio.get<List<dynamic>>(ApiPaths.familyContacts);
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FamilyContactModel.fromJson)
        .toList();
  }

  Future<FamilyContactModel> createContact({
    required String fullName,
    required String phoneNumber,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiPaths.familyContacts,
      data: {'fullName': fullName, 'phoneNumber': phoneNumber},
    );
    return FamilyContactModel.fromJson(response.data ?? const {});
  }
}
