import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider_app/main.dart';

void main() {
  testWidgets('renders provider requests screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProviderApp()));

    expect(find.text('Direct booking requests'), findsOneWidget);
    expect(find.text('Demo provider login'), findsOneWidget);
  });
}
