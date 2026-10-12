import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/app/care_sitter_app.dart';

void main() {
  testWidgets('CareSitter app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CareSitterApp()),
    );
    expect(find.byType(CareSitterApp), findsOneWidget);
  });
}
