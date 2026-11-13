import 'package:caresitter_customer/features/nutrition/data/sources/nutrition_disclaimer_ack_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps the existing key format and stores only a bool', () async {
    SharedPreferences.setMockInitialValues({
      'nutrition_disclaimer_ack:user-a:v1': true,
    });
    final store = NutritionDisclaimerAckStore();
    expect(await store.isAcknowledged('user-a', 'v1'), isTrue);
    expect(await store.isAcknowledged('user-b', 'v1'), isFalse);
    expect(await store.isAcknowledged('user-a', 'v2'), isFalse);
    await store.acknowledge('user-a', 'v2');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), {
      'nutrition_disclaimer_ack:user-a:v1',
      'nutrition_disclaimer_ack:user-a:v2',
    });
    expect(preferences.get('nutrition_disclaimer_ack:user-a:v2'), isTrue);
  });

  test('read errors propagate to the controller', () async {
    SharedPreferences.setMockInitialValues({
      'nutrition_disclaimer_ack:user-a:v1': 'invalid flag',
    });
    expect(NutritionDisclaimerAckStore().isAcknowledged('user-a', 'v1'),
        throwsA(isA<TypeError>()));
  });
}
