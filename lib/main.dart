import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe_seed_data.dart';
import 'recipe_expansion.dart';

const cream = Color(0xFFFFF8EE);
const peach = Color(0xFFF3B39B);
const rose = Color(0xFFD97B70);
const brown = Color(0xFF5B463B);
const sage = Color(0xFF8BAA8B);
const card = Color(0xFFFFFCF7);

class Recipe {
  final String id, title, category, time, description, country, imageUrl;
  final List<String> ingredients, steps;
  final bool favorite;
  const Recipe({required this.id, required this.title, required this.category, required this.time, required this.description, required this.ingredients, required this.steps, this.country = 'العالم العربي', this.favorite = false, this.imageUrl = ''});
  Recipe copyWith({bool? favorite, String? country, String? imageUrl}) => Recipe(id:id,title:title,category:category,time:time,description:description,ingredients:ingredients,steps:steps,country:country ?? this.country,favorite:favorite ?? this.favorite,imageUrl:imageUrl ?? this.imageUrl);
  bool get isExpandedCatalog => RegExp(r'^ar-[a-z]{2}-\d{3}$').hasMatch(id);
  Map<String,dynamic> toJson() => {'id':id,'title':title,'category':category,'time':time,'description':description,'country':country,'ingredients':ingredients,'steps':steps,'favorite':favorite,'imageUrl':imageUrl};
  factory Recipe.fromJson(Map<String,dynamic> j) => Recipe(
    id:j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
    title:j['title'] ?? '', category:j['category'] ?? 'بيتي', time:j['time'] ?? '',
    description:j['description'] ?? '', country:j['country'] ?? 'العالم العربي', ingredients:List<String>.from(j['ingredients'] ?? []),
    steps:List<String>.from(j['steps'] ?? []), favorite:j['favorite'] ?? false, imageUrl:j['imageUrl'] ?? '');
}


class SmartSuggestion {
  final Recipe recipe;
  final List<String> matched;
  final List<String> missing;
  final int score;
  final double coverage;
  final String reason;

  const SmartSuggestion({
    required this.recipe,
    required this.matched,
    required this.missing,
    required this.score,
    required this.coverage,
    required this.reason,
  });
}

class SmartRecipeEngine {
  static const Map<String, String> _aliases = {
    'egg': 'بيض', 'eggs': 'بيض', 'بيضة': 'بيض', 'بيضه': 'بيض',
    'cheese': 'جبن', 'جبنة': 'جبن', 'جبنه': 'جبن', 'جبن': 'جبن',
    'milk': 'لبن', 'حليب': 'لبن',
    'chicken': 'دجاج', 'فراخ': 'دجاج', 'دجاجة': 'دجاج', 'دجاجه': 'دجاج',
    'meat': 'لحم', 'beef': 'لحم', 'لحمة': 'لحم', 'لحمه': 'لحم',
    'potato': 'بطاطس', 'potatoes': 'بطاطس', 'بطاطا': 'بطاطس',
    'tomato': 'طماطم', 'tomatoes': 'طماطم', 'طماطم': 'طماطم', 'طماطه': 'طماطم',
    'onion': 'بصل', 'rice': 'ارز', 'رز': 'ارز', 'أرز': 'ارز', 'ارز': 'ارز',
    'pasta': 'مكرونه', 'macaroni': 'مكرونه', 'مكرونه': 'مكرونه', 'مكرونة': 'مكرونه',
    'garlic': 'ثوم', 'butter': 'زبد', 'زبدة': 'زبد',
    'oil': 'زيت', 'carrot': 'جزر', 'carrots': 'جزر', 'زيت زيتون': 'زيت زيتون', 'زيت الزيتون': 'زيت زيتون',
    'peas': 'بازلاء', 'بسلة': 'بازلاء',
    'bread': 'خبز', 'خبز': 'خبز', 'عيش': 'خبز',
    'black pepper': 'فلفل', 'pepper': 'فلفل', 'فلفل أسود': 'فلفل',
    'salt': 'ملح',
    'beans': 'فاصوليا', 'فاصوليا': 'فاصوليا', 'فاصوليا بيضاء': 'فاصوليا بيضاء', 'فاصوليا خضراء': 'فاصوليا خضراء', 'green beans': 'فاصوليا خضراء',
    'chickpeas': 'حمص', 'حمص بطحينة': 'حمص',
    'fava beans': 'فول', 'فول مدمس': 'فول',
    'lentils': 'عدس', 'عدس أصفر': 'عدس',
    'okra': 'بامية', 'eggplant': 'باذنجان',
    'zucchini': 'كوسه', 'كوسا': 'كوسه', 'كوسة': 'كوسه',
    'cauliflower': 'قرنبيط', 'shrimp': 'جمبري', 'prawns': 'جمبري', 'cucumber': 'خيار', 'خيار': 'خيار', 'lettuce': 'خس', 'خس': 'خس', 'pumpkin': 'قرع', 'قرع': 'قرع',
    'روبيان': 'جمبري', 'قريدس': 'جمبري', 'fish': 'سمك', 'سمكة': 'سمك',
    'yogurt': 'زبادي', 'لبن رايب': 'زبادي', 'tahini': 'طحينه',
    'طحينة': 'طحينه', 'لبنة': 'لبنه', 'لبنه': 'لبنه',
    'bulgur': 'برغل', 'freekeh': 'فريك', 'thyme': 'زعتر',
    'parsley': 'بقدونس', 'mint': 'نعناع', 'coriander': 'كزبره',
    'ليمون': 'ليمون', 'lemon': 'ليمون',
    'tomato sauce': 'طماطم', 'passata': 'طماطم', 'canned tomatoes': 'طماطم',
    'rice vermicelli': 'شعرية', 'vermicelli': 'شعرية', 'semolina': 'سميد',
    'olive oil': 'زيت زيتون', 'coconut': 'جوز الهند',
  };

  static const Set<String> _staples = {'ملح', 'فلفل', 'زيت', 'ماء', 'سكر', 'خل'};
  static const Set<String> _units = {
    'كوب', 'اكواب', 'كوبان', 'كوبين', 'ملعقة', 'ملاعق', 'ملعقه',
    'ملعقتان', 'ملعقتين', 'صغيرة', 'صغيره', 'كبيرة', 'كبيره',
    'جرام', 'غرام', 'كيلو', 'كجم', 'جم', 'مل', 'مليلتر', 'لتر',
    'قطعة', 'قطع', 'حبة', 'حبات', 'حبه', 'رشة', 'رشات', 'فص', 'فصوص',
    'رغيف', 'رغيفين', 'cup', 'cups', 'tbsp', 'tsp', 'tablespoon',
    'tablespoons', 'teaspoon', 'teaspoons', 'gram', 'grams', 'kg',
    'g', 'ml', 'liter', 'liters', 'clove', 'cloves', 'piece', 'pieces',
  };

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String normalize(String value) {
    var x = _fold(value).replaceAll(RegExp(r'[0-9٠-٩]+(?:[.,٫][0-9٠-٩]+)?'), ' ');
    x = x.split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !_units.contains(token))
        .join(' ')
        .trim();
    if (x.isEmpty) return '';
    final direct = _aliases[x];
    if (direct != null) return direct;
    x = x.replaceAll('ة', 'ه');
    return _aliases[x] ?? x;
  }

  static bool _isWordCodeUnit(String value, int index) {
    if (index < 0 || index >= value.length) return false;
    final code = value.codeUnitAt(index);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        (code >= 0x0600 && code <= 0x06ff);
  }

  static List<String> interpretIngredients(String value) {
    final chunks = value.split(
      RegExp(r'[,،;؛\n]+|\s+و(?=\s|[\u0600-\u06FF])\s*'),
    );
    final aliases = _aliases.keys.toList()
      ..sort((a, b) => _fold(b).length.compareTo(_fold(a).length));
    final result = <String>[];

    for (final chunk in chunks) {
      final text = _fold(chunk).replaceFirst(
        RegExp(r'^(?:الموجود عندي|متوفر عندي|عندي كمان|عندي بس|عندي|عندى|معايا|متوفر|الموجود)\s*'),
        '',
      ).trim();
      if (text.isEmpty) continue;

      final occupied = <List<int>>[];
      for (final alias in aliases) {
        final needle = _fold(alias);
        if (needle.isEmpty) continue;
        var start = 0;
        while (start <= text.length - needle.length) {
          final found = text.indexOf(needle, start);
          if (found < 0) break;
          final end = found + needle.length;
          final bounded = !_isWordCodeUnit(text, found - 1) && !_isWordCodeUnit(text, end);
          final overlaps = occupied.any((span) => found < span[1] && end > span[0]);
          if (bounded && !overlaps) {
            final canonical = normalize(alias);
            if (canonical.isNotEmpty && !result.contains(canonical)) result.add(canonical);
            occupied.add([found, end]);
          }
          start = found + 1;
        }
      }
      if (occupied.isEmpty) {
        final normalized = normalize(text);
        if (normalized.length >= 2 && !result.contains(normalized)) result.add(normalized);
      }
    }
    return result;
  }

  static bool _isAvailable(Set<String> pantry, String ingredient) =>
      pantry.contains(ingredient) ||
      (pantry.contains('فاصوليا') &&
          const {'فاصوليا بيضاء', 'فاصوليا خضراء'}.contains(ingredient));

  static int _minutes(String value) {
    final m = RegExp(r'(\d+)').firstMatch(value);
    return int.tryParse(m?.group(1) ?? '') ?? 45;
  }

  static String _reason(
    double coverage,
    List<String> matched,
    List<String> missing,
    Recipe recipe,
    Map<String, int> history,
  ) {
    if (coverage >= .85 && missing.isEmpty) return 'جاهزة تقريبًا بالموجود عندك';
    if (coverage >= .7) return 'مناسبة جدًا ومحتاجة مكونات قليلة';
    if (matched.length >= 3) return 'بتستفيد من كذا مكوّن موجود عندك';
    if ((history[recipe.id] ?? 0) > 0) return 'وصفة بتحب ترجع لها والمكونات مناسبة';
    return 'أقرب وصفة متاحة من مكوناتك الحالية';
  }

  static List<SmartSuggestion> rank(
    List<String> pantry,
    List<Recipe> recipes, {
    Map<String, int> history = const {},
    List<String> recentRecipeIds = const [],
  }) {
    final normalizedPantry = pantry.map(normalize).where((x) => x.isNotEmpty).toSet();
    final results = <SmartSuggestion>[];

    for (final recipe in recipes) {
      final useful = recipe.ingredients.where((x) => !_staples.contains(normalize(x))).toList();
      final matched = <String>[];
      final missing = <String>[];

      final normalizedIngredients = <String>{};
      for (final ingredient in useful) {
        final normalized = normalize(ingredient);
        if (normalized.isEmpty) {
          missing.add(ingredient);
          continue;
        }
        normalizedIngredients.add(normalized);
        if (_isAvailable(normalizedPantry, normalized)) {
          matched.add(ingredient);
        } else {
          missing.add(ingredient);
        }
      }

      if (matched.isEmpty) continue;

      final coverage = useful.isEmpty ? 0.0 : matched.length / useful.length;
      final relevantPantry = normalizedPantry.difference(_staples);
      final pantryUse = relevantPantry.isEmpty
          ? 0.0
          : relevantPantry.where((item) =>
              normalizedIngredients.contains(item) ||
              (item == 'فاصوليا' &&
                  normalizedIngredients.any((value) =>
                      value == 'فاصوليا بيضاء' || value == 'فاصوليا خضراء'))).length /
              relevantPantry.length;

      var score = (coverage * 55).round();
      score += (matched.length * 7).clamp(0, 28).toInt();
      score += (pantryUse * 10).round();
      score -= (missing.length * 3).clamp(0, 18).toInt();
      if (recipe.favorite) score += 6;
      score += ((history[recipe.id] ?? 0) * 2).clamp(0, 8).toInt();

      final recentIndex = recentRecipeIds.indexOf(recipe.id);
      if (recentIndex >= 0 && recentIndex < 3) score -= 5 - recentIndex;

      final minutes = _minutes(recipe.time);
      if (minutes <= 20) score += 3;
      if (minutes >= 90) score -= 2;

      results.add(SmartSuggestion(
        recipe: recipe,
        matched: matched,
        missing: missing,
        score: score.clamp(1, 100).toInt(),
        coverage: coverage,
        reason: _reason(coverage, matched, missing, recipe, history),
      ));
    }

    results.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      final c = b.coverage.compareTo(a.coverage);
      if (c != 0) return c;
      final m = a.missing.length.compareTo(b.missing.length);
      if (m != 0) return m;
      return _minutes(a.recipe.time).compareTo(_minutes(b.recipe.time));
    });
    return results;
  }
}

class CookingConversion {
  static Map<String, dynamic> convert({
    required String from,
    required String to,
    required int temperatureC,
    required int minutes,
  }) {
    var temp = temperatureC.toDouble();
    var time = minutes.toDouble();
    if (from == to) {
    } else if (from == 'فرن عادي' && to == 'فرن بمروحة') {
      temp -= 15;
      time *= .9;
    } else if (from == 'فرن بمروحة' && to == 'فرن عادي') {
      temp += 15;
      time *= 1.1;
    } else if ((from == 'فرن عادي' || from == 'فرن بمروحة') && to == 'قلاية هوائية') {
      temp -= 20;
      time *= .8;
    } else if (from == 'قلاية هوائية' && (to == 'فرن عادي' || to == 'فرن بمروحة')) {
      temp += 20;
      time *= 1.25;
    }
    return {
      'temperatureC': temp.round().clamp(80, 260),
      'minutes': time.ceil().clamp(1, 240),
    };
  }
}

class RecipeDiagnostics {
  final List<Recipe> recipes;
  final int repairedCount;
  final int duplicateIngredientsRemoved;
  final int duplicateStepsRemoved;
  final List<String> manualIssues;
  const RecipeDiagnostics({
    required this.recipes,
    required this.repairedCount,
    required this.duplicateIngredientsRemoved,
    required this.duplicateStepsRemoved,
    required this.manualIssues,
  });
}

RecipeDiagnostics repairRecipeLibrary(List<Recipe> source) {
  var repairedCount = 0;
  var duplicateIngredientsRemoved = 0;
  var duplicateStepsRemoved = 0;
  final manualIssues = <String>[];
  final repaired = <Recipe>[];
  final usedIds = <String>{};

  for (var index = 0; index < source.length; index++) {
    final original = source[index];
    var id = original.id.trim();
    if (id.isEmpty || usedIds.contains(id)) {
      id = 'repaired-${index + 1}';
    }
    usedIds.add(id);

    final title = original.title.trim().isEmpty
        ? 'وصفة بدون اسم ${index + 1}'
        : original.title.trim();
    final time = original.time.trim().isEmpty ? 'غير محدد' : original.time.trim();
    final description = original.description.trim().isEmpty
        ? '$title بطابع بيتي.'
        : original.description.trim();

    final ingredients = <String>[];
    for (final value in original.ingredients.map((x) => x.trim()).where((x) => x.isNotEmpty)) {
      final key = SmartRecipeEngine.normalize(value);
      if (ingredients.any((x) => SmartRecipeEngine.normalize(x) == key)) {
        duplicateIngredientsRemoved++;
      } else {
        ingredients.add(value);
      }
    }

    final steps = <String>[];
    for (final value in original.steps.map((x) => x.trim()).where((x) => x.isNotEmpty)) {
      if (steps.any((x) => x.toLowerCase() == value.toLowerCase())) {
        duplicateStepsRemoved++;
      } else {
        steps.add(value);
      }
    }

    if (ingredients.isEmpty) manualIssues.add('$title: محتاجة مكونات.');
    if (steps.isEmpty) manualIssues.add('$title: محتاجة خطوات تحضير.');

    if (id != original.id ||
        title != original.title.trim() ||
        time != original.time.trim() ||
        description != original.description.trim() ||
        original.category.trim().isEmpty ||
        original.country.trim().isEmpty ||
        ingredients.length != original.ingredients.length ||
        steps.length != original.steps.length ||
        original.imageUrl.trim() != original.imageUrl) {
      repairedCount++;
    }

    repaired.add(Recipe(
      id: id,
      title: title,
      category: original.category.trim().isEmpty ? 'بيتي' : original.category.trim(),
      time: time,
      description: description,
      country: original.country.trim().isEmpty ? 'العالم العربي' : original.country.trim(),
      ingredients: ingredients,
      steps: steps,
      favorite: original.favorite,
      imageUrl: original.imageUrl.trim(),
    ));
  }

  return RecipeDiagnostics(
    recipes: repaired,
    repairedCount: repairedCount,
    duplicateIngredientsRemoved: duplicateIngredientsRemoved,
    duplicateStepsRemoved: duplicateStepsRemoved,
    manualIssues: manualIssues,
  );
}

Widget recipeVisual(Recipe r, {double size = 58}) {
  final fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: peach.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Icon(Icons.restaurant_rounded, color: rose, size: size * .5),
  );
  if (r.imageUrl.trim().isEmpty) return fallback;
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.network(
      r.imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    ),
  );
}

Widget recipeHeroImage(Recipe r, {double height = 190}) {
  if (r.imageUrl.trim().isEmpty) return const SizedBox.shrink();
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.network(
      r.imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        color: peach.withValues(alpha: .2),
        child: const Icon(Icons.broken_image_outlined, color: rose, size: 55),
      ),
    ),
  );
}

void showCookingConversionDialog(BuildContext context, Recipe recipe) {
  var from = recipe.steps.any(
    (x) => RegExp(r'(قلاية|اير فراير|air fryer)', caseSensitive: false).hasMatch(x),
  ) ? 'قلاية هوائية' : 'فرن عادي';
  var to = from == 'قلاية هوائية' ? 'فرن عادي' : 'قلاية هوائية';
  final temperature = TextEditingController(text: '180');
  final match = RegExp(r'(\d+)').firstMatch(recipe.time);
  final minutes = TextEditingController(text: (int.tryParse(match?.group(1) ?? '30') ?? 30).toString());

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setDialogState) {
        final converted = CookingConversion.convert(
          from: from,
          to: to,
          temperatureC: int.tryParse(temperature.text) ?? 180,
          minutes: int.tryParse(minutes.text) ?? 30,
        );
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: cream,
            title: const Text('تحويل طريقة الطهي', style: TextStyle(color: brown, fontWeight: FontWeight.w900)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: from,
                decoration: const InputDecoration(labelText: 'من'),
                items: const [
                  DropdownMenuItem(value: 'فرن عادي', child: Text('فرن عادي')),
                  DropdownMenuItem(value: 'فرن بمروحة', child: Text('فرن بمروحة')),
                  DropdownMenuItem(value: 'قلاية هوائية', child: Text('قلاية هوائية')),
                ],
                onChanged: (v) => setDialogState(() => from = v ?? from),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: to,
                decoration: const InputDecoration(labelText: 'إلى'),
                items: const [
                  DropdownMenuItem(value: 'فرن عادي', child: Text('فرن عادي')),
                  DropdownMenuItem(value: 'فرن بمروحة', child: Text('فرن بمروحة')),
                  DropdownMenuItem(value: 'قلاية هوائية', child: Text('قلاية هوائية')),
                ],
                onChanged: (v) => setDialogState(() => to = v ?? to),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: temperature,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الحرارة °C'),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الدقائق'),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'المقترح: ${converted['temperatureC']}°C لمدة ${converted['minutes']} دقيقة',
                style: const TextStyle(color: brown, fontWeight: FontWeight.w900),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
            ],
          ),
        );
      },
    ),
  );
}

List<String> parseIngredients(String value) => value
    .split(RegExp(r'[,،\n]+'))
    .map((x) => x.trim())
    .where((x) => x.isNotEmpty)
    .fold<List<String>>([], (out, item) {
      if (!out.any((x) => SmartRecipeEngine.normalize(x) == SmartRecipeEngine.normalize(item))) {
        out.add(item);
      }
      return out;
    });

List<String> parseSteps(String value) => value
    .split(RegExp(r'[\r\n]+'))
    .map((x) => x.trim().replaceFirst(RegExp(r'^\d+[.)\-]\s*'), ''))
    .where((x) => x.isNotEmpty)
    .toList();



List<Recipe> starterRecipes() => [
  ...arabicRecipeSeedData.map((entry) => Recipe.fromJson(entry)),
  ...expandedArabicRecipeData.map((entry) => Recipe.fromJson(entry)),
];

List<Recipe> filterRecipes(List<Recipe> source, String query, {String country = 'الكل'}) {
  final q = SmartRecipeEngine.normalize(query);
  final tokens = q.split(' ').where((x) => x.isNotEmpty).toList();
  return source.where((r) {
    if (country != 'الكل' && r.country != country) return false;
    if (tokens.isEmpty) return true;
    final haystack = [r.title, r.country, r.category, ...r.ingredients]
        .map(SmartRecipeEngine.normalize)
        .join(' ');
    return tokens.every(haystack.contains);
  }).toList();
}

Future<void> _backupPreference(SharedPreferences prefs, String key) async {
  final current = prefs.get(key);
  if (current == null) return;
  final backupKey = '${key}_backup';
  if (current is String) {
    try {
      jsonDecode(current);
      await prefs.setString(backupKey, current);
    } catch (_) {
      // Keep the last-known-good backup if the primary value is malformed.
    }
  } else if (current is List<String>) {
    await prefs.setStringList(backupKey, List<String>.from(current));
  }
}

String? _safePreferenceString(SharedPreferences prefs, String key) {
  try { return prefs.getString(key); } catch (_) { return null; }
}

List<String>? _safePreferenceStringList(SharedPreferences prefs, String key) {
  try { return prefs.getStringList(key); } catch (_) { return null; }
}

Map<String, dynamic> _readJsonMapWithBackup(SharedPreferences prefs, String key) {
  for (final candidateKey in [key, '${key}_backup']) {
    final raw = _safePreferenceString(prefs, candidateKey);
    if (raw == null) continue;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Try the retained valid copy instead of failing app startup.
    }
  }
  return <String, dynamic>{};
}

void main() => runApp(const CozyMamaApp());

class CozyMamaApp extends StatefulWidget {
  const CozyMamaApp({super.key});
  @override State<CozyMamaApp> createState() => _CozyMamaAppState();
}

class _CozyMamaAppState extends State<CozyMamaApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  int tab = 0;
  List<String> pantry = ['بطاطس','بيض','طماطم','بصل','أرز','دجاج','مكرونة','جبنة'];
  List<Recipe> recipes = starterRecipes();
  Map<String, int> recipeUseCount = {};
  List<String> recentRecipeIds = [];
  String recipeQuery = '';
  String selectedCountry = 'الكل';
  final TextEditingController recipeSearchController = TextEditingController();
  Timer? _recipeSearchDebounce;

  @override void initState() { super.initState(); load(); }

  @override void dispose() {
    _recipeSearchDebounce?.cancel();
    recipeSearchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final rawCandidates = [
      _safePreferenceString(p, 'recipes'),
      _safePreferenceString(p, 'recipes_backup'),
    ];
    final ingredientCandidates = [
      _safePreferenceStringList(p, 'pantry'),
      _safePreferenceStringList(p, 'pantry_backup'),
    ];
    final historyCandidates = [
      _safePreferenceString(p, 'recipe_use_count'),
      _safePreferenceString(p, 'recipe_use_count_backup'),
    ];
    final savedRecent = _safePreferenceStringList(p, 'recent_recipe_ids') ??
        _safePreferenceStringList(p, 'recent_recipe_ids_backup') ??
        const <String>[];

    List<Recipe>? savedRecipes;
    for (final candidate in rawCandidates) {
      if (candidate == null) continue;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is! List) continue;
        savedRecipes = decoded.whereType<Map>()
            .map((entry) => Recipe.fromJson(Map<String, dynamic>.from(entry))).toList();
        break;
      } catch (_) {
        // Fall back to backup and keep startup alive.
      }
    }

    Map<String, dynamic>? savedHistory;
    for (final candidate in historyCandidates) {
      if (candidate == null) continue;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map) {
          savedHistory = Map<String, dynamic>.from(decoded);
          break;
        }
      } catch (_) {
        // Fall back to the most recent valid history copy.
      }
    }

    if (!mounted) return;
    setState(() {
      _invalidateRecipeCaches();
      if (savedRecipes != null) {
        final seeds = starterRecipes();
        final seedIds = seeds.map((e) => e.id).toSet();
        final savedById = {for (final recipe in savedRecipes) recipe.id: recipe};
        recipes = seeds.map((seed) {
          final old = savedById.remove(seed.id);
          return old == null ? seed : seed.copyWith(favorite: old.favorite);
        }).toList()
          ..addAll(savedById.values.where((recipe) => !seedIds.contains(recipe.id)));
      }
      final ing = ingredientCandidates.firstWhere((candidate) => candidate != null, orElse: () => null);
      if (ing != null) pantry = List<String>.from(ing);
      if (savedHistory != null) {
        recipeUseCount = savedHistory.map((key, value) => MapEntry(key, value is num ? value.toInt() : 0));
      }
      recentRecipeIds = List<String>.from(savedRecent);
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await _backupPreference(p, 'recipes');
    await _backupPreference(p, 'pantry');
    await _backupPreference(p, 'recipe_use_count');
    await _backupPreference(p, 'recent_recipe_ids');
    await p.setString('recipes', jsonEncode(recipes.map((e) => e.toJson()).toList()));
    await p.setStringList('pantry', pantry);
    await p.setString('recipe_use_count', jsonEncode(recipeUseCount));
    await p.setStringList('recent_recipe_ids', recentRecipeIds);
  }

  List<SmartSuggestion>? _smartSuggestionsCache;
  List<Recipe>? _filteredRecipesCache;
  List<Recipe>? _filteredRecipesSource;
  List<Recipe>? _favoriteRecipesCache;
  List<Recipe>? _favoriteRecipesSource;
  String? _filteredRecipesQuery;
  String? _filteredRecipesCountry;

  void _invalidateSmartSuggestions() => _smartSuggestionsCache = null;

  void _invalidateRecipeCaches() {
    _invalidateSmartSuggestions();
    _filteredRecipesCache = null;
    _filteredRecipesSource = null;
    _favoriteRecipesCache = null;
    _favoriteRecipesSource = null;
  }

  List<SmartSuggestion> get smartSuggestions =>
      _smartSuggestionsCache ??= SmartRecipeEngine.rank(
        pantry,
        recipes,
        history: recipeUseCount,
        recentRecipeIds: recentRecipeIds,
      );

  List<Recipe> get suggestions =>
      smartSuggestions.map((x) => x.recipe).toList();

  List<Recipe> get favoriteRecipes {
    if (_favoriteRecipesCache != null && identical(_favoriteRecipesSource, recipes)) {
      return _favoriteRecipesCache!;
    }
    final result = recipes.where((recipe) => recipe.favorite).toList();
    _favoriteRecipesSource = recipes;
    _favoriteRecipesCache = result;
    return result;
  }
  List<Recipe> get filteredRecipes {
    if (_filteredRecipesCache != null &&
        identical(_filteredRecipesSource, recipes) &&
        _filteredRecipesQuery == recipeQuery &&
        _filteredRecipesCountry == selectedCountry) {
      return _filteredRecipesCache!;
    }
    final result = filterRecipes(recipes, recipeQuery, country: selectedCountry);
    _filteredRecipesSource = recipes;
    _filteredRecipesQuery = recipeQuery;
    _filteredRecipesCountry = selectedCountry;
    _filteredRecipesCache = result;
    return result;
  }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'مطبخي الدافي',
    navigatorKey:navigatorKey,theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:rose)),
    home:Directionality(textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(backgroundColor:cream,elevation:0,title:const Text('مطبخي الدافي',style:TextStyle(fontWeight:FontWeight.w900,color:brown)),actions:[
        IconButton(onPressed:diagnoseAndRepairRecipes,icon:const Icon(Icons.health_and_safety_rounded,color:brown)),IconButton(onPressed:showPantry,icon:const Icon(Icons.kitchen_rounded,color:brown))
      ]),
      body:IndexedStack(index:tab,children:[home(), recipesPage(), suggestionsPage(), favoritesPage(), smartKitchenPage()]),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),backgroundColor:card,indicatorColor:peach.withValues(alpha: .35),destinations:const[
        NavigationDestination(icon:Icon(Icons.home_rounded),label:'الرئيسية'),
        NavigationDestination(icon:Icon(Icons.menu_book_rounded),label:'وصفاتي'),
        NavigationDestination(icon:Icon(Icons.auto_awesome_rounded),label:'اقترحي لي'),
        NavigationDestination(icon:Icon(Icons.favorite_rounded),label:'المفضلة'),
        NavigationDestination(icon:Icon(Icons.auto_awesome_motion_rounded),label:'المطبخ الذكي')
      ]),
      floatingActionButton:tab == 1 ? FloatingActionButton.extended(backgroundColor:rose,foregroundColor:Colors.white,onPressed:addRecipe,icon:const Icon(Icons.add_rounded),label:const Text('وصفة جديدة')) : null
    ))
  );

  Widget home() {
    final picks = smartSuggestions.take(3).toList();
    return ListView(padding:const EdgeInsets.fromLTRB(18,8,18,30),children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFFE7D8),Color(0xFFF8D7D0)]),borderRadius:BorderRadius.circular(28)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('أهلاً يا ماما',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:brown)),
        SizedBox(height:8),Text('خلّي المطبخ أهدى شوية… قوليلي إيه موجود عندك وأنا أساعدك تختاري وجبة.',style:TextStyle(fontSize:15,height:1.5,color:brown))
      ])),
      const SizedBox(height:20), section('ماذا نطبخ اليوم؟','حسب المكونات اللي عندك'),
      const SizedBox(height:10),
      if(picks.isEmpty) empty('ضيفي مكوناتك عشان أقدر أقترح لك وجبات.') else ...picks.map(smartSuggestionCard),
      const SizedBox(height:12), section('وصفاتك','كل وصفات البيت في مكان واحد'),
      const SizedBox(height:10), ...recipes.take(2).map(recipeCard)
    ]);
  }

  Widget recipesPage() {
    final list = filteredRecipes;
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 0), child: section('وصفاتي', '${list.length} ظاهر من ${recipes.length} وصفة')),
      Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 8), child: TextField(
        controller: recipeSearchController,
        onChanged: (value) {
          _recipeSearchDebounce?.cancel();
          _recipeSearchDebounce = Timer(const Duration(milliseconds: 140), () {
            if (mounted) setState(() => recipeQuery = value);
          });
        },
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(hintText: 'ابحثي باسم الوصفة أو المكوّن…', prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: recipeQuery.isEmpty ? null : IconButton(onPressed: () {
             _recipeSearchDebounce?.cancel();
             recipeSearchController.clear();
             setState(() => recipeQuery = '');
           }, icon: const Icon(Icons.clear_rounded)),
          filled: true, fillColor: Colors.white70, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      )),
      Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 12), child: DropdownButtonFormField<String>(
        initialValue: selectedCountry, isExpanded: true, onChanged: (value) => setState(() => selectedCountry = value ?? 'الكل'),
        decoration: InputDecoration(labelText: 'المطبخ', filled: true, fillColor: Colors.white70, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
        items: [const DropdownMenuItem(value: 'الكل', child: Text('كل المطابخ')), ...arabWorldCountries.map((country) => DropdownMenuItem(value: country, child: Text(country)))],
      )),
      Expanded(child: list.isEmpty ? Center(child: empty('مفيش وصفات مطابقة للبحث أو المطبخ المختار.')) : ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 90), itemCount: list.length, itemBuilder: (_, index) => recipeCard(list[index]),
      )),
    ]);
  }
  Widget suggestionsPage() {
    final list = smartSuggestions;
    return ListView.builder(
      padding: const EdgeInsets.all(18), itemCount: list.isEmpty ? 1 : list.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFE7F0E5), borderRadius: BorderRadius.circular(24)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome_rounded, color: sage, size: 30), SizedBox(height: 8),
            Text('اقتراحات ذكية من مطبخك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: brown)),
            SizedBox(height: 5), Text('الترتيب بيتعلم من المفضلة والوصفات اللي طبختيها، وبيوضح لك المتوفر والناقص.', style: TextStyle(color: brown, height: 1.4)),
          ]),
          );
        }
        if (list.isEmpty) return empty('لسه مفيش اقتراح مناسب. ضيفي مكونات أكتر أو احفظي وصفات جديدة.');
        return smartSuggestionCard(list[index - 1]);
      },
    );
  }
  Widget smartKitchenPage() => SmartKitchenPage(
    recipes: recipes,
    pantry: pantry,
    history: recipeUseCount,
    recentRecipeIds: recentRecipeIds,
    onPantryChanged: (items) {
      setState(() {
        pantry = List<String>.from(items);
        _invalidateSmartSuggestions();
      });
      save();
    },
    onCooked: (recipe) {
      setState(() {
        _invalidateSmartSuggestions();
        recipeUseCount[recipe.id] = (recipeUseCount[recipe.id] ?? 0) + 1;
        recentRecipeIds = [recipe.id, ...recentRecipeIds.where((id) => id != recipe.id)].take(12).toList();
      });
      save();
    },
  );

  Widget favoritesPage() {
    final list = favoriteRecipes;
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: list.isEmpty ? 3 : list.length + 2,
      itemBuilder: (_, index) {
        if (index == 0) return section('المفضلة', 'الوصفات اللي بتحبي ترجعي لها');
        if (index == 1) return const SizedBox(height: 12);
        if (list.isEmpty) return empty('اضغطي على القلب جنب أي وصفة عشان تلاقيها هنا بسرعة.');
        return recipeCard(list[index - 2]);
      },
    );
  }

  Widget section(String title,String sub) => Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:brown)),const SizedBox(height:3),Text(sub,style:TextStyle(color:brown.withValues(alpha: .65)))])),
    const Icon(Icons.restaurant_menu_rounded,color:rose)
  ]);

  Widget smartSuggestionCard(SmartSuggestion suggestion) {
    final r = suggestion.recipe;
    final percent = (suggestion.coverage * 100).round();
    final missingPreview = suggestion.missing.take(3).join('، ');
    final missingText = suggestion.missing.isEmpty
        ? 'المكونات الأساسية كلها موجودة'
        : 'ناقص: $missingPreview${suggestion.missing.length > 3 ? '…' : ''}';

    return Card(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => details(r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                recipeVisual(r),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: brown)),
                      const SizedBox(height: 5),
                      Text('${r.category} • ${r.time}', style: TextStyle(color: brown.withValues(alpha: .65))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: suggestion.score >= 75 ? const Color(0xFFE2F1E2) : const Color(0xFFFFEBDD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('${suggestion.score}%', style: const TextStyle(color: brown, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(suggestion.reason, style: const TextStyle(color: brown, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('متوفر: ${suggestion.matched.take(4).join('، ')}', style: TextStyle(color: brown.withValues(alpha: .78))),
              const SizedBox(height: 3),
              Text(missingText, style: TextStyle(color: suggestion.missing.isEmpty ? sage : brown.withValues(alpha: .65))),
              const SizedBox(height: 6),
              Text('$percent% من المكونات المطلوبة موجودة', style: TextStyle(color: brown.withValues(alpha: .55), fontSize: 12)),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => toggleFavorite(r),
                  icon: Icon(
                    r.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: r.favorite ? rose : brown.withValues(alpha: .5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget recipeCard(Recipe r) => Card(color:card,elevation:0,margin:const EdgeInsets.only(bottom:12),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:InkWell(
    borderRadius:BorderRadius.circular(22),onTap:()=>details(r),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
      recipeVisual(r),
      const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(r.title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:brown)),const SizedBox(height:5),
        Text('${r.country} • ${r.category} • ${r.time}',style:TextStyle(color:brown.withValues(alpha: .65)))
      ])),
      IconButton(onPressed:()=>toggleFavorite(r),icon:Icon(r.favorite?Icons.favorite_rounded:Icons.favorite_border_rounded,color:r.favorite?rose:brown.withValues(alpha: .5)))
    ])))
  );

  Widget empty(String text) => Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(20)),child:Text(text,style:const TextStyle(color:brown,height:1.5)));

  void markCooked(Recipe r) {
    setState(() {
      _invalidateSmartSuggestions();
      recipeUseCount[r.id] = (recipeUseCount[r.id] ?? 0) + 1;
      recentRecipeIds = [r.id, ...recentRecipeIds.where((id) => id != r.id)].take(12).toList();
    });
    save();
    ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
      SnackBar(content: Text('اتسجلت ${r.title} في تاريخ وصفاتك')),
    );
  }

  Future<void> diagnoseAndRepairRecipes() async {
    final result = repairRecipeLibrary(recipes);
    setState(() {
      recipes = result.recipes;
      _invalidateRecipeCaches();
    });
    await save();
    if (!mounted) return;
    showDialog<void>(
      context: navigatorKey.currentState!.context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: cream,
          title: const Text('فحص الوصفات', style: TextStyle(color: brown, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('وصفات اتصلحت: ${result.repairedCount}'),
              Text('تكرارات مكونات اتشالت: ${result.duplicateIngredientsRemoved}'),
              Text('تكرارات خطوات اتشالت: ${result.duplicateStepsRemoved}'),
              const SizedBox(height: 10),
              if (result.manualIssues.isEmpty)
                const Text('مفيش مشاكل محتاجة تدخل يدوي.')
              else ...[
                const Text('محتاج إدخال يدوي:', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                ...result.manualIssues.take(20).map((x) => Text('• $x', style: const TextStyle(height: 1.4))),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام')),
          ],
        ),
      ),
    );
  }

  void toggleFavorite(Recipe r) {
    setState(() {
      recipes = recipes.map((x) => x.id == r.id ? x.copyWith(favorite: !x.favorite) : x).toList();
      _invalidateRecipeCaches();
    });
    save();
  }

  void details(Recipe r) => showModalBottomSheet(context:navigatorKey.currentState!.context,isScrollControlled:true,backgroundColor:cream,builder:(_)=>Directionality(textDirection:TextDirection.rtl,child:DraggableScrollableSheet(expand:false,initialChildSize:.72,builder:(_,c)=>ListView(controller:c,padding:const EdgeInsets.all(22),children:[
    recipeHeroImage(r),const SizedBox(height:12),Text(r.title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:brown)),const SizedBox(height:7),
    Text('${r.category} • ${r.time}',style:TextStyle(color:brown.withValues(alpha: .65))),const SizedBox(height:15),
    Text(r.description,style:const TextStyle(color:brown,height:1.5)),
    const SizedBox(height:12),
    Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:()=>showCookingConversionDialog(navigatorKey.currentState!.context,r),icon:const Icon(Icons.swap_horiz_rounded),label:const Text('تحويل الطهي'))]),const SizedBox(height:8),FilledButton.icon(
      onPressed: () {
        markCooked(r);
        Navigator.pop(navigatorKey.currentState!.context);
      },
      icon: const Icon(Icons.check_circle_outline_rounded),
      label: const Text('طبختها اليوم'),
    ),
    const SizedBox(height:18),
    const Text('المكونات',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:brown)),const SizedBox(height:8),
    ...r.ingredients.map((x)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.check_circle_rounded,color:sage),title:Text(x))),
    const SizedBox(height:10),const Text('الطريقة',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:brown)),const SizedBox(height:8),
    ...r.steps.asMap().entries.map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(radius:15,backgroundColor:peach,child:Text((e.key+1).toString(),style:const TextStyle(color:brown))),title:Text(e.value)))
  ]))));

  Future<void> addRecipe() async {
    final title=TextEditingController(), ingredients=TextEditingController(), steps=TextEditingController(), time=TextEditingController(), imageUrl=TextEditingController();
    await showDialog(context:navigatorKey.currentState!.context,builder:(dialogContext)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
      backgroundColor:cream,title:const Text('وصفة جديدة',style:TextStyle(color:brown,fontWeight:FontWeight.w900)),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(title,'اسم الوصفة'),field(ingredients,'المكونات — افصلي بينها بفاصلة'),field(steps,'الطريقة — كل خطوة في سطر'),field(time,'الوقت، مثال: 30 دقيقة'),field(imageUrl,'رابط صورة الوصفة (اختياري)')
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء')),FilledButton(onPressed:(){
        if(title.text.trim().isEmpty)return;
        final r=Recipe(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),category:'بيتي',time:time.text.trim().isEmpty?'غير محدد':time.text.trim(),description:'وصفة من مطبخك.',country:'وصفة شخصية',ingredients:parseIngredients(ingredients.text),steps:parseSteps(steps.text),imageUrl:imageUrl.text.trim());
        setState(() { recipes = [r, ...recipes]; _invalidateRecipeCaches(); });save();Navigator.pop(dialogContext);
      },child:const Text('حفظ'))]
    )));
  }

  Widget field(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,maxLines:label.contains('الطريقة')?3:1,decoration:InputDecoration(labelText:label,filled:true,fillColor:Colors.white70,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none))));

  Future<void> showPantry() async {
    final c=TextEditingController();
    await showModalBottomSheet(context:navigatorKey.currentState!.context,backgroundColor:cream,isScrollControlled:true,builder:(_)=>StatefulBuilder(builder:(context,sheet)=>Directionality(textDirection:TextDirection.rtl,child:Padding(
      padding:EdgeInsets.fromLTRB(18,20,18,MediaQuery.of(context).viewInsets.bottom+20),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('مكونات البيت',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:brown)),
        const SizedBox(height:6),const Text('اكتبي الموجود عندك عشان الاقتراحات تبقى أذكى.',style:TextStyle(color:brown)),const SizedBox(height:14),
        Wrap(spacing:7,runSpacing:7,children:pantry.map((x)=>InputChip(label:Text(x),onDeleted:(){setState(() { pantry = List<String>.from(pantry)..remove(x); _invalidateSmartSuggestions(); });sheet((){});save();})).toList()),
        const SizedBox(height:10),Row(children:[
          Expanded(child:TextField(controller:c,decoration:InputDecoration(hintText:'مثال: جزر',filled:true,fillColor:Colors.white70,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)))),
          const SizedBox(width:8),IconButton.filled(onPressed:(){final x=c.text.trim();if(x.isNotEmpty&&!pantry.any((item)=>SmartRecipeEngine.normalize(item)==SmartRecipeEngine.normalize(x))){setState(() { pantry = [...pantry, x]; _invalidateSmartSuggestions(); });sheet((){});c.clear();save();}},icon:const Icon(Icons.add_rounded))
        ])
      ])
    ))));
  }
}


class SmartKitchenPage extends StatefulWidget {
  final List<Recipe> recipes;
  final List<String> pantry;
  final Map<String, int> history;
  final List<String> recentRecipeIds;
  final ValueChanged<List<String>> onPantryChanged;
  final ValueChanged<Recipe> onCooked;

  const SmartKitchenPage({
    super.key,
    required this.recipes,
    required this.pantry,
    required this.history,
    required this.recentRecipeIds,
    required this.onPantryChanged,
    required this.onCooked,
  });

  @override
  State<SmartKitchenPage> createState() => _SmartKitchenPageState();
}

class _SmartKitchenPageState extends State<SmartKitchenPage> {
  final queryController = TextEditingController();
  String query = '';
  String country = 'الكل';
  String category = 'الكل';
  String difficulty = 'الكل';
  int? maxMinutes;
  List<String> pantry = [];
  Map<String, int> expiry = <String, int>{};
  List<String> shopping = [];
  Map<String, String> notes = <String, String>{};
  Map<String, int> ratings = <String, int>{};
  bool excludeRecent = false;
  String? _rankedCacheKey;
  List<SmartSuggestion>? _rankedCache;
  String? _seasonalCacheKey;
  List<Recipe>? _seasonalCache;
  List<Recipe>? _filterOptionsSource;
  List<String> _countryOptionsCache = const <String>[];
  List<String> _categoryOptionsCache = const <String>[];
  String? _discoveryCacheKey;
  List<Recipe>? _discoveryCache;

  @override
  void initState() {
    super.initState();
    pantry = List<String>.from(widget.pantry);
    _loadSmartData();
  }

  @override
  void didUpdateWidget(covariant SmartKitchenPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pantry, widget.pantry)) {
      pantry = List<String>.from(widget.pantry);
      _rankedCacheKey = null;
    }
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  int _minutes(Recipe recipe) {
    final match = RegExp(r'(\d+)').firstMatch(recipe.time);
    return int.tryParse(match?.group(1) ?? '') ?? 45;
  }

  String _difficulty(Recipe recipe) {
    final complexity = recipe.ingredients.length + recipe.steps.length + (_minutes(recipe) ~/ 30);
    if (_minutes(recipe) <= 30 && complexity <= 9) return 'سهل';
    if (_minutes(recipe) <= 70 && complexity <= 15) return 'متوسط';
    return 'متقدم';
  }

  String _season() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return 'الربيع';
    if (month >= 6 && month <= 8) return 'الصيف';
    if (month >= 9 && month <= 11) return 'الخريف';
    return 'الشتاء';
  }

  List<String> _understandIngredients(String value) =>
      SmartRecipeEngine.interpretIngredients(value);

  Future<void> _loadSmartData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedExpiry = _readJsonMapWithBackup(prefs, 'smart_expiry');
    final savedNotes = _readJsonMapWithBackup(prefs, 'smart_notes');
    final savedRatings = _readJsonMapWithBackup(prefs, 'smart_ratings');
    final savedShopping = _safePreferenceStringList(prefs, 'smart_shopping') ??
        _safePreferenceStringList(prefs, 'smart_shopping_backup') ?? const <String>[];
    if (!mounted) return;
    setState(() {
      expiry = savedExpiry.map((key, value) => MapEntry(key, value is num ? value.toInt() : 0));
      notes = savedNotes.map((key, value) => MapEntry(key, value.toString()));
      ratings = savedRatings.map((key, value) => MapEntry(key, value is num ? value.toInt() : 0));
      shopping = List<String>.from(savedShopping);
    });
  }

  Future<void> _saveSmartData() async {
    final prefs = await SharedPreferences.getInstance();
    await _backupPreference(prefs, 'smart_expiry');
    await _backupPreference(prefs, 'smart_shopping');
    await _backupPreference(prefs, 'smart_notes');
    await _backupPreference(prefs, 'smart_ratings');
    await prefs.setString('smart_expiry', jsonEncode(expiry));
    await prefs.setStringList('smart_shopping', shopping);
    await prefs.setString('smart_notes', jsonEncode(notes));
    await prefs.setString('smart_ratings', jsonEncode(ratings));
  }

  void _setPantry(List<String> values) {
    final clean = <String>[];
    for (final value in values.map((x) => x.trim()).where((x) => x.isNotEmpty)) {
      final normalized = SmartRecipeEngine.normalize(value);
      if (!clean.any((x) => SmartRecipeEngine.normalize(x) == normalized)) {
        clean.add(value);
      }
    }
    pantry = clean;
    widget.onPantryChanged(clean);
    setState(() {});
    _saveSmartData();
  }

  List<Recipe> _filtered() {
    final q = SmartRecipeEngine.normalize(query);
    final tokens = q.split(' ').where((x) => x.isNotEmpty).toList();
    final interpreted = _understandIngredients(query);

    return widget.recipes.where((recipe) {
      if (country != 'الكل' && recipe.country != country) return false;
      if (category != 'الكل' && recipe.category != category) return false;
      if (difficulty != 'الكل' && _difficulty(recipe) != difficulty) return false;
      if (maxMinutes != null && _minutes(recipe) > maxMinutes!) return false;
      if (excludeRecent && widget.recentRecipeIds.contains(recipe.id)) return false;
      if (tokens.isEmpty || interpreted.isNotEmpty) return true;

      final haystack = [
        recipe.title,
        recipe.country,
        recipe.category,
        ...recipe.ingredients,
      ].map(SmartRecipeEngine.normalize).join(' ');
      return tokens.every(haystack.contains);
    }).toList();
  }

  List<SmartSuggestion> _ranked() {
    final cacheKey = jsonEncode([
      identityHashCode(widget.recipes),
      query, pantry, country, category, difficulty, maxMinutes, excludeRecent,
      widget.history, widget.recentRecipeIds,
    ]);
    if (_rankedCache != null && _rankedCacheKey == cacheKey) return _rankedCache!;

    final candidates = _filtered();
    final interpreted = _understandIngredients(query);
    final available = interpreted.isNotEmpty ? interpreted : pantry;
    final result = available.isEmpty
        ? candidates.take(60).map((recipe) => SmartSuggestion(
            recipe: recipe,
            matched: const [],
            missing: recipe.ingredients,
            score: widget.recentRecipeIds.contains(recipe.id) ? 75 : 90,
            coverage: 0,
            reason: 'اختيار اكتشاف من الكتالوج بدون مكوّنات محددة',
          )).toList()
        : SmartRecipeEngine.rank(
            available, candidates,
            history: widget.history,
            recentRecipeIds: widget.recentRecipeIds,
          ).take(60).toList();

    _rankedCacheKey = cacheKey;
    _rankedCache = result;
    return result;
  }

  List<String> _seasonKeywords() {
    switch (_season()) {
      case 'الربيع':
        return ['فول', 'حمص', 'سلطة', 'ليمون'];
      case 'الصيف':
        return ['طماطم', 'باذنجان', 'كوسه', 'سلطة'];
      case 'الخريف':
        return ['قرع', 'عدس', 'شوربة', 'تمر'];
      default:
        return ['شوربة', 'عدس', 'طاجن', 'قرفة'];
    }
  }

  List<Recipe> _seasonal() {
    final cacheKey = jsonEncode([
      identityHashCode(widget.recipes), widget.recentRecipeIds, _season(),
    ]);
    if (_seasonalCache != null && _seasonalCacheKey == cacheKey) return _seasonalCache!;
    final keys = _seasonKeywords().map(SmartRecipeEngine.normalize).toList();
    final result = widget.recipes.where((recipe) {
      if (widget.recentRecipeIds.contains(recipe.id)) return false;
      final hay = [
        recipe.title, recipe.category, ...recipe.ingredients,
      ].map(SmartRecipeEngine.normalize).join(' ');
      return keys.any(hay.contains);
    }).take(12).toList();
    _seasonalCacheKey = cacheKey;
    _seasonalCache = result;
    return result;
  }

  Recipe? _categoryRecipe(String contains, {String? avoid}) {
    for (final recipe in widget.recipes) {
      if (avoid != null && recipe.id == avoid) continue;
      if (SmartRecipeEngine.normalize(recipe.category).contains(contains)) {
        return recipe;
      }
    }
    return null;
  }

  Future<void> _addShopping(Iterable<String> missing) async {
    for (final item in missing) {
      final normalized = SmartRecipeEngine.normalize(item);
      if (!shopping.any((x) => SmartRecipeEngine.normalize(x) == normalized)) {
        shopping.add(item);
      }
    }
    await _saveSmartData();
    if (mounted) setState(() {});
  }

  Future<void> _addPantry() async {
    final controller = TextEditingController();
    DateTime? selectedDate;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مكوّن للمخزن'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'المكوّن'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                );
                if (picked != null) setDialogState(() => selectedDate = picked);
              },
              icon: const Icon(Icons.event_rounded),
              label: Text(
                selectedDate == null
                    ? 'تاريخ الانتهاء اختياري'
                    : 'الانتهاء ${selectedDate!.day}/${selectedDate!.month}',
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                if (selectedDate != null) {
                  expiry[SmartRecipeEngine.normalize(value)] =
                      selectedDate!.millisecondsSinceEpoch;
                }
                _setPantry([...pantry, value]);
                Navigator.pop(dialogContext);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  List<String> _expiringSoon() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return pantry.where((item) {
      final end = expiry[SmartRecipeEngine.normalize(item)];
      return end != null &&
          end >= now &&
          end - now <= const Duration(days: 3).inMilliseconds;
    }).toList();
  }

  void _substitutions() {
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('بدائل شائعة'),
        content: SingleChildScrollView(
          child: Text(
            'زبادي ← لبن رايب أو لبنة مخففة\n'
            'زبد ← سمن أو زيت نباتي\n'
            'ليمون ← خل خفيف بكمية أقل\n'
            'سكر ← عسل أو تمر مهروس حسب الوصفة\n'
            'جبن ← لبنة أو جبن قريب في الرطوبة والملوحة\n'
            'زيت زيتون ← زيت نباتي عند الحاجة',
            style: TextStyle(height: 1.6),
          ),
        ),
      ),
    );
  }

  String _scaledIngredient(String value, int servings) {
    if (servings == 4) return value;
    final match = RegExp(r'^(\d+(?:[.,]\d+)?)\s+(.+)$').firstMatch(value.trim());
    if (match == null) return value;

    final original = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (original == null) return value;

    final scaled = original * servings / 4;
    final shown = scaled == scaled.roundToDouble()
        ? scaled.toInt().toString()
        : scaled.toStringAsFixed(1);
    return '$shown ${match.group(2)!}';
  }

  Future<void> _recipeDetails(Recipe recipe) async {
    int servings = 4;
    final note = TextEditingController(text: notes[recipe.id] ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          maxChildSize: .96,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            children: [
              recipeHeroImage(recipe),
              const SizedBox(height: 12),
              Text(
                recipe.title,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: brown),
              ),
              const SizedBox(height: 5),
              Text('${recipe.country} • ${recipe.category} • ${recipe.time} • ${_difficulty(recipe)}'),
              const SizedBox(height: 12),
              Text(recipe.description, style: const TextStyle(height: 1.5)),
              if (recipe.isExpandedCatalog) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFE8D6), borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'تنبيه: دي وصفة من الكتالوج الموسّع؛ المكونات والخطوات مبدئية وقد تكون عامة. راجعيها قبل الاعتماد عليها.',
                    style: TextStyle(color: brown, height: 1.45),
                  ),
                ),
              ],
              if (recipe.ingredients.any((item) => !RegExp(r'^\s*[0-9٠-٩]').hasMatch(item))) ...[
                const SizedBox(height: 8),
                const Text(
                  'المكونات اللي من غير كميات مش هتتغيّر تلقائيًا مع تعديل عدد الأفراد.',
                  style: TextStyle(color: brown, height: 1.4),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                const Text('لـ', style: TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: servings > 1 ? () => setSheetState(() => servings--) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text(servings.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(
                  onPressed: () => setSheetState(() => servings++),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
                const Text('أفراد'),
              ]),
              const Text('المكونات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brown)),
              ...recipe.ingredients.map((item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline_rounded, color: sage),
                title: Text(_scaledIngredient(item, servings)),
              )),
              Wrap(spacing: 7, runSpacing: 7, children: [
                OutlinedButton.icon(onPressed:()=>showCookingConversionDialog(context,recipe),icon:const Icon(Icons.swap_horiz_rounded),label:const Text('تحويل الطهي')),const SizedBox(height:8),FilledButton.icon(
                  onPressed: () {
                    widget.onCooked(recipe);
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('طبختها'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addShopping(
                    recipe.ingredients.where(
                      (item) => !pantry.any(
                        (p) => SmartRecipeEngine.normalize(p) ==
                            SmartRecipeEngine.normalize(item),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('أضف الناقص'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _cookMode(recipe);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('وضع الطبخ'),
                ),
              ]),
              const SizedBox(height: 14),
              const Text('الطريقة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brown)),
              ...recipe.steps.asMap().entries.map((entry) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text((entry.key + 1).toString())),
                  title: Text(entry.value, style: const TextStyle(height: 1.45)),
                ),
              )),
              const SizedBox(height: 10),
              const Text('ملاحظتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: brown)),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'اكتبي ملاحظة للمرة الجاية…'),
                onChanged: (value) => notes[recipe.id] = value,
                onEditingComplete: _saveSmartData,
              ),
              Row(
                children: [
                  const Text('تقييمي:'),
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () async {
                        ratings[recipe.id] = i;
                        await _saveSmartData();
                        if (mounted) setSheetState(() {});
                      },
                      icon: Icon(
                        i <= (ratings[recipe.id] ?? 0)
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    note.dispose();
  }

  Future<void> _cookMode(Recipe recipe) async {
    int step = 0;
    int seconds = 0;
    bool closed = false;
    Timer? timer;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('وضع الطبخ', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text('الخطوة ${step + 1} من ${recipe.steps.length}'),
              const SizedBox(height: 12),
              Text(
                recipe.steps[step],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, height: 1.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (seconds > 0)
                Text(
                  '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final minutes in [1, 5, 10, 20])
                    OutlinedButton(
                      onPressed: () {
                        timer?.cancel();
                        setSheetState(() => seconds = minutes * 60);
                        timer = Timer.periodic(const Duration(seconds: 1), (_) {
                          if (closed) return;
                          if (seconds <= 1) {
                            timer?.cancel();
                            setSheetState(() => seconds = 0);
                          } else {
                            setSheetState(() => seconds--);
                          }
                        });
                      },
                      child: Text('$minutes د'),
                    ),
                  FilledButton(
                    onPressed: () {
                      if (step + 1 < recipe.steps.length) {
                        setSheetState(() => step++);
                      } else {
                        widget.onCooked(recipe);
                        closed = true;
                        timer?.cancel();
                        Navigator.pop(sheetContext);
                      }
                    },
                    child: Text(step + 1 < recipe.steps.length ? 'التالي' : 'تم'),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );

    closed = true;
    timer?.cancel();
  }

  void _mealBuilder() {
    final ranked = _ranked();
    Recipe? main = ranked.isNotEmpty
        ? ranked.first.recipe
        : (widget.recipes.isEmpty ? null : widget.recipes.first);

    final side = _categoryRecipe('جانب', avoid: main?.id) ??
        _categoryRecipe('مقبل', avoid: main?.id);
    final salad = _categoryRecipe('سلط', avoid: main?.id);
    final drink = _categoryRecipe('مشروب', avoid: main?.id);
    final dessert = _categoryRecipe('حلو', avoid: main?.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('وجبة كاملة', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          _mealLine('الطبق الرئيسي', main),
          _mealLine('جانبي / مقبل', side),
          _mealLine('سلطة', salad),
          _mealLine('مشروب', drink),
          _mealLine('حلو', dessert),
        ]),
      ),
    );
  }

  Widget _mealLine(String label, Recipe? recipe) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(recipe == null ? Icons.remove_circle_outline_rounded : Icons.restaurant_rounded),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(recipe?.title ?? 'لا يوجد تطابق'),
    trailing: recipe == null ? null : Text('${_minutes(recipe)} د'),
  );

  Widget _suggestionCard(SmartSuggestion item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _recipeDetails(item.recipe),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(child: Icon(Icons.restaurant_rounded)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.recipe.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text('${item.score}%', style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 7),
            Text(item.reason),
            if (item.matched.isNotEmpty) Text('موجود: ${item.matched.take(5).join('، ')}'),
            if (item.missing.isNotEmpty) Text('ناقص: ${item.missing.take(5).join('، ')}'),
            Wrap(spacing: 4, runSpacing: 4, children: [
              Chip(label: Text(item.recipe.country)),
              Chip(label: Text(item.recipe.category)),
              Chip(label: Text(item.recipe.time)),
              Chip(label: Text(_difficulty(item.recipe))),
            ]),
            if (item.missing.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addShopping(item.missing),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('أضف الناقص'),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _cookMode(item.recipe),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('ابدئي الطبخ'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pantryCard() {
    final expiring = _expiringSoon();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
              child: Text('مخزن البيت', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            ),
            IconButton(onPressed: _addPantry, icon: const Icon(Icons.add_circle_rounded)),
          ]),
          Text('${pantry.length} مكوّن محفوظ Offline'),
          if (expiring.isNotEmpty)
            Text('قريب من الانتهاء: ${expiring.join('، ')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: pantry.map((item) => InputChip(
              label: Text(item),
              onDeleted: () => _setPantry([...pantry]..remove(item)),
            )).toList(),
          ),
        ]),
      ),
    );
  }

  Widget _shoppingCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('قائمة التسوق', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          IconButton(
            onPressed: shopping.isEmpty
                ? null
                : () async {
                    shopping.clear();
                    await _saveSmartData();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ]),
        if (shopping.isEmpty)
          const Text('المكونات الناقصة من الوصفات تتجمع هنا.')
        else
          ...shopping.map((item) => CheckboxListTile(
            dense: true,
            value: false,
            onChanged: (_) async {
              shopping.remove(item);
              await _saveSmartData();
              if (mounted) setState(() {});
            },
            title: Text(item),
          )),
      ]),
    ),
  );

  Widget _filters() {
    if (!identical(_filterOptionsSource, widget.recipes)) {
      _filterOptionsSource = widget.recipes;
      _countryOptionsCache = <String>{'الكل', ...widget.recipes.map((r) => r.country)}.toList()..sort();
      _categoryOptionsCache = <String>{'الكل', ...widget.recipes.map((r) => r.category)}.toList()..sort();
    }
    final countries = _countryOptionsCache;
    final categories = _categoryOptionsCache;

    return Wrap(spacing: 6, runSpacing: 6, children: [
      DropdownButton<String>(
        value: countries.contains(country) ? country : 'الكل',
        items: countries.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
        onChanged: (v) => setState(() => country = v ?? 'الكل'),
      ),
      DropdownButton<String>(
        value: categories.contains(category) ? category : 'الكل',
        items: categories.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
        onChanged: (v) => setState(() => category = v ?? 'الكل'),
      ),
      DropdownButton<String>(
        value: difficulty,
        items: const [
          DropdownMenuItem(value: 'الكل', child: Text('كل المستويات')),
          DropdownMenuItem(value: 'سهل', child: Text('سهل')),
          DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
          DropdownMenuItem(value: 'متقدم', child: Text('متقدم')),
        ],
        onChanged: (v) => setState(() => difficulty = v ?? 'الكل'),
      ),
      DropdownButton<int?>(
        value: maxMinutes,
        items: const [
          DropdownMenuItem<int?>(value: null, child: Text('أي وقت')),
          DropdownMenuItem<int?>(value: 15, child: Text('حتى 15 د')),
          DropdownMenuItem<int?>(value: 30, child: Text('حتى 30 د')),
          DropdownMenuItem<int?>(value: 60, child: Text('حتى ساعة')),
          DropdownMenuItem<int?>(value: 120, child: Text('حتى ساعتين')),
        ],
        onChanged: (v) => setState(() => maxMinutes = v),
      ),
    ]);
  }

  List<Recipe> _discoverNew() {
    final cacheKey = jsonEncode([identityHashCode(widget.recipes), widget.recentRecipeIds]);
    if (_discoveryCache != null && _discoveryCacheKey == cacheKey) {
      return _discoveryCache!;
    }
    final result = widget.recipes
        .where((recipe) => !widget.recentRecipeIds.contains(recipe.id) && !recipe.favorite)
        .take(4)
        .toList();
    _discoveryCacheKey = cacheKey;
    _discoveryCache = result;
    return result;
  }

  Widget _dashboard() {
    final ranked = _ranked();
    final interpreted = _understandIngredients(query);
    final seasonal = _seasonal();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const Text('المطبخ الذكي', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('اكتبي المكونات أو جملة كاملة. الموسم الحالي: ${_season()}'),
        const SizedBox(height: 12),
        TextField(
          controller: queryController,
          onChanged: (value) => setState(() => query = value),
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'مثال: عندي فراخ ورز وبصل وعايز حاجة في نص ساعة',
            prefixIcon: const Icon(Icons.auto_awesome_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      queryController.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        if (interpreted.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'فهمت: ${interpreted.join('، ')}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        const SizedBox(height: 7),
        _filters(),
        const SizedBox(height: 5),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _mealBuilder,
              icon: const Icon(Icons.dinner_dining_rounded),
              label: const Text('وجبة كاملة'),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _substitutions,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('البدائل'),
            ),
          ),
        ]),
        const SizedBox(height: 9),
        _pantryCard(),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(
            child: Text('أفضل النتائج', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          TextButton(
            onPressed: () => setState(() => excludeRecent = !excludeRecent),
            child: Text(excludeRecent ? 'أظهر المتكرر' : 'قلل التكرار'),
          ),
        ]),
        if (ranked.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('مفيش تطابق كفاية. زوّدي مكوّن أو اكتبي اسم مكوّن واحد زي فاصوليا.'),
            ),
          )
        else
          ...ranked.take(8).map(_suggestionCard),
        const SizedBox(height: 8),
        const Text('اقتراحات الموسم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ...seasonal.take(4).map((recipe) => _suggestionCard(SmartSuggestion(
          recipe: recipe,
          matched: const [],
          missing: const [],
          score: 88,
          coverage: 0,
          reason: 'اختيار موسمي مع تقليل التكرار',
        ))),
        const SizedBox(height: 8),
        const Text('اكتشفي الجديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ..._discoverNew().map(
          (recipe) => _suggestionCard(SmartSuggestion(
            recipe: recipe,
            matched: const [],
            missing: const [],
            score: 90,
            coverage: 0,
            reason: 'وصفة جديدة عليك',
          )),
        ),
        const SizedBox(height: 8),
        _shoppingCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: _dashboard(),
  );
}
