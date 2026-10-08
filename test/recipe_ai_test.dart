import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  test('smart engine prioritizes recipes matching eggs and cheese', () {
    final recipes = starterRecipes();
    final results = SmartRecipeEngine.rank(['بيض', 'جبنة'], recipes);
    expect(results, isNotEmpty);
    expect(results.first.recipe.title, anyOf('بيض بالجبنة والطماطم', 'عجة البطاطس بالجبنة', 'شكشوكة بالجبنة', 'مكرونة بالبيض والجبنة'));
    expect(results.first.matched.length, greaterThanOrEqualTo(2));
    expect(results.first.coverage, greaterThan(0.2));
  });

  test('smart engine understands English ingredient names and Arabic variants', () {
    final results = SmartRecipeEngine.rank(['eggs', 'cheese'], starterRecipes());
    expect(results.first.matched.length, greaterThanOrEqualTo(2));
    expect(results.first.recipe.ingredients.any((x) => SmartRecipeEngine.normalize(x) == 'بيض'), isTrue);
  });

  test('ingredient and step parsing accepts Arabic punctuation and real new lines', () {
    expect(parseIngredients('بيض، جبنة, طماطم\nبيض'), ['بيض', 'جبنة', 'طماطم']);
    expect(parseSteps('1) اكسر البيض\n2. أضيفي الجبنة\r\n3- قدمي فورًا'), ['اكسر البيض', 'أضيفي الجبنة', 'قدمي فورًا']);
  });

  test('smart engine can still suggest a close recipe from one available ingredient', () {
    final results = SmartRecipeEngine.rank(['بطاطس'], starterRecipes());
    expect(results, isNotEmpty);
    expect(results.first.matched.first, 'بطاطس');
  });
}
