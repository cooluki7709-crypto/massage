import 'package:customer_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('renders customer booking entry screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));

    expect(find.text('Demo customer login'), findsOneWidget);
    expect(find.text('Providers'), findsWidgets);
  });
}
