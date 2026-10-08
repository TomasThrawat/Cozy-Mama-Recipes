import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  testWidgets('app renders', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    expect(find.text('مطبخي الدافي'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('وصفاتي'), findsOneWidget);
  });

  testWidgets('navigation and pantry controls respond', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('وصفاتي'));
    await tester.pumpAndSettle();
    expect(find.text('وصفة جديدة'), findsOneWidget);

    await tester.tap(find.text('وصفة جديدة'));
    await tester.pumpAndSettle();
    expect(find.text('اسم الوصفة'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.kitchen_rounded));
    await tester.pumpAndSettle();
    expect(find.text('مكونات البيت'), findsOneWidget);
  });

  testWidgets('recipe details and favorite controls respond', (tester) async {
    await tester.pumpWidget(const CozyMamaApp());
    await tester.pumpAndSettle();

    final favorite = find.byIcon(Icons.favorite_border_rounded).first;
    await tester.tap(favorite);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

    final recipeTitle = find.text('مكرونة بالصوص الكريمي');
    expect(recipeTitle, findsWidgets);
    await tester.tap(recipeTitle.first);
    await tester.pumpAndSettle();

    expect(find.text('المكونات'), findsOneWidget);
    expect(find.text('الطريقة'), findsOneWidget);
  });
}