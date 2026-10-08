import 'package:flutter_test/flutter_test.dart';
import 'package:cozy_mama_recipes/main.dart';

void main() {
  test('smart engine prioritizes recipes matching eggs and cheese', () {
    final recipes = starterRecipes();
    final res