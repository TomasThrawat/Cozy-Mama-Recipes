import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  test('smart engine prioritizes recipes matching eggs and cheese', () {
    final results = SmartRecipeEngine.rank(['بيض', 'جبنة'], starterRecipes());

    expect(results, isNotEmpty);
    expect(
      results.first.recipe.title,
      anyOf(
        'بيض بالجبنة والطماطم',
        'عجة البطاطس بالجبنة',
        'شكشوكة بالجبنة',
        'مكرونة بالبيض والجبنة',
        'توست بالبيض والجبنة',
      ),
    );
    expect(results.first.matched.length, greaterThanOrEqualTo(2));
    expect(results.first.coverage, greaterThan(0.2));
  });

  test('smart engine understands English ingredient names and Arabic variants', () {
    final results =
        SmartRecipeEngine.rank(['eggs', 'cheese'], starterRecipes());

    expect(results, isNotEmpty);
    expect(results.first.matched.length, greaterThanOrEqualTo(2));
    expect(
      results.first.recipe.ingredients.any(
        (x) => SmartRecipeEngine.normalize(x) == 'بيض',
      ),
      isTrue,
    );
  });

  test('ingredient and step parsing accepts Arabic punctuation and real new lines', () {
    expect(
      parseIngredients('بيض، جبنة, طماطم\nبيض'),
      ['بيض', 'جبنة', 'طماطم'],
    );
    expect(
      parseSteps('1) اكسر البيض\n2. أضيفي الجبنة\r\n3- قدمي فورًا'),
      ['اكسر البيض', 'أضيفي الجبنة', 'قدمي فورًا'],
    );
  });

  test('smart engine can still suggest a close recipe from one available ingredient', () {
    final results = SmartRecipeEngine.rank(['بطاطس'], starterRecipes());

    expect(results, isNotEmpty);
    expect(results.first.matched.first, 'بطاطس');
  });

  test('Arabic catalog covers common food and beans are directly discoverable', () {
    final recipes = starterRecipes();
    expect(recipes.length, equals(1000));
    expect(recipes.map((r) => r.id).toSet().length, equals(1000));
    expect(recipes.map((r) => r.country).toSet().length, equals(23));
    final results = SmartRecipeEngine.rank(['فاصوليا'], recipes);
    expect(results.any((x) => x.recipe.title.contains('فاصوليا')), isTrue);
    expect(results.length, greaterThan(5));
  });

  test('smart ranking can use cooking history', () {
    final recipes = starterRecipes();
    final base = SmartRecipeEngine.rank(['بيض', 'جبنة'], recipes);
    final first = base.first.recipe;
    final learned = SmartRecipeEngine.rank(
      ['بيض', 'جبنة'],
      recipes,
      history: {first.id: 4},
      recentRecipeIds: const [],
    );
    expect(learned.first.recipe.id, equals(first.id));
  });

  
  test('ingredient normalization removes Arabic and English quantities and units', () {
    expect(SmartRecipeEngine.normalize('2 كوب طماطم'), 'طماطم');
    expect(SmartRecipeEngine.normalize('١٠٠ جرام جبنة'), 'جبن');
    expect(SmartRecipeEngine.normalize('2 cups tomatoes'), 'طماطم');
  });

  test('matching does not treat generic oil as olive oil', () {
    final recipe = Recipe(
      id: 'olive-oil-test',
      title: 'اختبار زيت الزيتون',
      category: 'سلطة',
      time: '10 دقائق',
      description: 'اختبار المطابقة',
      ingredients: const ['زيت زيتون'],
      steps: const ['اخلطي المكونات.'],
    );
    expect(SmartRecipeEngine.rank(['زيت'], [recipe]), isEmpty);
    expect(SmartRecipeEngine.rank(['زيت زيتون'], [recipe]), hasLength(1));
  });

  test('ingredient parser handles Arabic lists and distinguishes bean types', () {
    expect(
      SmartRecipeEngine.interpretIngredients('عندي 2 بيضة وجبنة و3 حبات طماطم'),
      ['بيض', 'جبن', 'طماطم'],
    );
    expect(
      SmartRecipeEngine.interpretIngredients('فاصوليا بيضاء، لبن رايب'),
      ['فاصوليا بيضاء', 'زبادي'],
    );
    expect(
      SmartRecipeEngine.rank(['فاصوليا بيضاء'], starterRecipes())
          .where((item) => item.recipe.title.contains('فاصوليا خضراء')),
      isEmpty,
    );
  });

  test('expanded catalogue recipes are explicitly marked as provisional', () {
    final recipe = starterRecipes().firstWhere((item) => item.isExpandedCatalog);
    expect(recipe.description, contains('مبدئية'));
    expect(recipe.isExpandedCatalog, isTrue);
  });

}

