import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  testWidgets('واجهة التطبيق الأساسية تظهر', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    expect(find.text('مطبخي الدافي'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('اقترحي لي'), findsOneWidget);
  });
}
