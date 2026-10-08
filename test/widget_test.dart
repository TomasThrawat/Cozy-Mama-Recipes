import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  testWidgets('app renders', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    expect(find.text('أهلاً يا ماما'), findsOneWidget);
    expect(find.text('ماذا نطبخ اليوم؟'), findsOneWidget);
    expect(find.text('وصفاتك'), findsOneWidget);
  });

  testWidgets('navigation and pantry controls respond', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('وصفاتي'));
    await tester.pumpAndSettle();
    expect(find.text('وصفاتي'), findsWidgets);

    await tester.tap(find.text('اقترحي لي'));
    await tester.pumpAndSettle();
    expect(find.text('اقتراحات من مطبخك'), findsOneWidget);

    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.kitchen_rounded));
    await tester.pumpAndSettle();
    expect(find.text('مكونات البيت'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();
  });

  testWidgets('recipe details and favorite controls respond', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('وصفاتي'));
    await tester.pumpAndSettle();

    final borderFinder = find.byIcon(Icons.favorite_border_rounded);
    final beforeBorderCount = borderFinder.evaluate().length;
    expect(beforeBorderCount, greaterThan(0));

    await tester.tap(borderFinder.first);
    await tester.pumpAndSettle();
    expect(
      find.byIcon(Icons.favorite_border_rounded).evaluate().length,
      beforeBorderCount - 1,
    );

    final recipeTitle = find.text(starterRecipes().first.title);
    expect(recipeTitle, findsOneWidget);
    await tester.tap(recipeTitle);
    await tester.pumpAndSettle();

    expect(find.text('المكونات'), findsOneWidget);

    final methodFinder = find.text('الطريقة');
    await tester.scrollUntilVisible(
      methodFinder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(methodFinder, findsOneWidget);

    final lastStepFinder = find.text(starterRecipes().first.steps.last);
    await tester.scrollUntilVisible(
      lastStepFinder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(lastStepFinder, findsOneWidget);
  });
}
