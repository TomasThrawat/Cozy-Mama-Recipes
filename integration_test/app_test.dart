import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main navigation and smart kitchen respond on Android', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    expect(find.text('أهلاً يا ماما'), findsOneWidget);
    expect(find.text('ماذا نطبخ اليوم؟'), findsOneWidget);

    await tester.tap(find.text('وصفاتي').first);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('وصفاتي'), findsWidgets);

    await tester.tap(find.text('اقترحي لي').first);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('اقتراحات ذكية من مطبخك'), findsOneWidget);

    await tester.tap(find.text('المطبخ الذكي').first);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('مخزن البيت'), findsOneWidget);
    expect(find.text('وجبة كاملة'), findsOneWidget);
    expect(find.text('البدائل'), findsOneWidget);
  });
}
