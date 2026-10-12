import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/app/push/notification_deep_link_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/app/care_sitter_app.dart';

void main() {
  testWidgets('CareSitter app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [
        notificationDeepLinkServiceProvider
            .overrideWith(createNotificationDeepLinkService)
      ], child: const CareSitterApp()),
    );
    expect(find.byType(CareSitterApp), findsOneWidget);
  });
}
