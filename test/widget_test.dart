import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  testWidgets('app renders', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    expect(find.text('أهلاً يا ماما'), findsOneWidget);
    expect(find.text('ماذا نطبخ اليوم؟'), findsOneWidget);
  });

  testWidgets('navigation and pantry controls respond', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('وصفاتي'));
    await tester.pumpAndSettle();
    expect(find.text('وصفاتي'), findsWidgets);

    await tester.tap(find.text('اقترحي لي'));
    await tester.pumpAndSettle();
    expect(find.text('اقتراحات ذكية من مطبخك'), findsOneWidget);

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

  testWidgets('smart kitchen features are reachable', (tester) async {
  await tester.pumpWidget(const CozyMamaApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('المطبخ الذكي'));
  await tester.pumpAndSettle();
  expect(find.text('المطبخ الذكي'), findsWidgets);
  expect(find.text('مخزن البيت'), findsOneWidget);
  expect(find.text('وجبة كاملة'), findsOneWidget);
  expect(find.text('البدائل'), findsOneWidget);
});

  test('cooking conversion is deterministic', () {
    final air = CookingConversion.convert(
      from: 'فرن عادي',
      to: 'قلاية هوائية',
      temperatureC: 200,
      minutes: 50,
    );
    expect(air['temperatureC'], 180);
    expect(air['minutes'], 40);
    final oven = CookingConversion.convert(
      from: 'قلاية هوائية',
      to: 'فرن عادي',
      temperatureC: 180,
      minutes: 40,
    );
    expect(oven['temperatureC'], 200);
    expect(oven['minutes'], 50);
  });

  test('recipe image persists through JSON', () {
    final recipe = Recipe(
      id: 'photo-test',
      title: 'وصفة صورة',
      category: 'بيتي',
      time: '20 دقيقة',
      description: 'اختبار',
      ingredients: const ['بيض'],
      steps: const ['اخفقي البيض.'],
      imageUrl: 'https://example.com/recipe.jpg',
    );
    expect(Recipe.fromJson(recipe.toJson()).imageUrl, 'https://example.com/recipe.jpg');
  });

  test('recipe diagnostics repairs duplicates safely', () {
    final result = repairRecipeLibrary([
      Recipe(
        id: '',
        title: '',
        category: '',
        time: '',
        description: '',
        ingredients: const ['بيض', 'بيضة'],
        steps: const ['خطوة', 'خطوة'],
      ),
    ]);
    expect(result.repairedCount, 1);
    expect(result.duplicateIngredientsRemoved, 1);
    expect(result.duplicateStepsRemoved, 1);
    expect(result.recipes.first.id, 'repaired-1');
    expect(result.manualIssues, isEmpty);
  });

  testWidgets('smart kitchen labels resolve values instead of showing raw templates', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المطبخ الذكي'));
    await tester.pumpAndSettle();

    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join('\n');
    expect(visibleText, isNot(contains(r'${')));
    expect(visibleText, isNot(contains('{{')));
    expect(find.textContaining('الموسم الحالي:'), findsOneWidget);
    expect(find.textContaining('مكوّن محفوظ Offline'), findsOneWidget);
  });

}
