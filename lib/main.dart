import 'dart:convert';
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
  final String id, title, category, time, description, country;
  final List<String> ingredients, steps;
  final bool favorite;
  const Recipe({required this.id, required this.title, required this.category, required this.time, required this.description, required this.ingredients, required this.steps, this.country = 'العالم العربي', this.favorite = false});
  Recipe copyWith({bool? favorite, String? country}) => Recipe(id:id,title:title,category:category,time:time,description:description,ingredients:ingredients,steps:steps,country:country ?? this.country,favorite:favorite ?? this.favorite);
  Map<String,dynamic> toJson() => {'id':id,'title':title,'category':category,'time':time,'description':description,'country':country,'ingredients':ingredients,'steps':steps,'favorite':favorite};
  factory Recipe.fromJson(Map<String,dynamic> j) => Recipe(
    id:j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
    title:j['title'] ?? '', category:j['category'] ?? 'بيتي', time:j['time'] ?? '',
    description:j['description'] ?? '', country:j['country'] ?? 'العالم العربي', ingredients:List<String>.from(j['ingredients'] ?? []),
    steps:List<String>.from(j['steps'] ?? []), favorite:j['favorite'] ?? false);
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
    'tomato': 'طماطم', 'tomatoes': 'طماطم',
    'onion': 'بصل', 'rice': 'ارز', 'رز': 'ارز', 'أرز': 'ارز',
    'pasta': 'مكرونه', 'macaroni': 'مكرونه', 'مكرونه': 'مكرونه', 'مكرونة': 'مكرونه',
    'garlic': 'ثوم', 'butter': 'زبد', 'زبدة': 'زبد',
    'oil': 'زيت', 'carrot': 'جزر', 'carrots': 'جزر',
    'peas': 'بازلاء', 'بسلة': 'بازلاء',
    'bread': 'خبز', 'خبز': 'خبز', 'عيش': 'خبز',
    'black pepper': 'فلفل', 'pepper': 'فلفل', 'فلفل أسود': 'فلفل',
    'salt': 'ملح',
    'beans': 'فاصوليا', 'فاصوليا بيضاء': 'فاصوليا', 'فاصوليا خضراء': 'فاصوليا',
    'green beans': 'فاصوليا', 'chickpeas': 'حمص', 'حمص بطحينة': 'حمص',
    'fava beans': 'فول', 'فول مدمس': 'فول',
    'lentils': 'عدس', 'عدس أصفر': 'عدس',
    'okra': 'بامية', 'eggplant': 'باذنجان',
    'zucchini': 'كوسه', 'كوسا': 'كوسه', 'كوسة': 'كوسه',
    'cauliflower': 'قرنبيط', 'shrimp': 'جمبري', 'prawns': 'جمبري',
    'روبيان': 'جمبري', 'قريدس': 'جمبري', 'fish': 'سمك', 'سمكة': 'سمك',
    'yogurt': 'زبادي', 'لبن رايب': 'زبادي', 'tahini': 'طحينه',
    'طحينة': 'طحينه', 'لبنة': 'لبنه', 'لبنه': 'لبنه',
    'bulgur': 'برغل', 'freekeh': 'فريك', 'thyme': 'زعتر',
    'parsley': 'بقدونس', 'mint': 'نعناع', 'coriander': 'كزبره',
    'ليمون': 'ليمون', 'lemon': 'ليمون',
    'tomato sauce': 'طماطم', 'passata': 'طماطم', 'canned tomatoes': 'طماطم',
    'rice vermicelli': 'شعرية', 'vermicelli': 'شعرية', 'semolina': 'سميد',
    'olive oil': 'زيت زيتون', 'yogurt': 'زبادي', 'coconut': 'جوز الهند',
  };

  static const Set<String> _staples = {'ملح', 'فلفل', 'زيت', 'ماء', 'سكر', 'خل'};

  static String normalize(String value) {
    var x = value.toLowerCase().trim();
    x = x.replaceAll(RegExp(r'\b\d+(?:[.,]\d+)?\b'), ' ');
    x = x.replaceAll(RegExp(r'\b(?:كوب|أكواب|ملعقة|ملاعق|جرام|غرام|كيلو|كجم|مل|لتر|قطعة|حبة|حبات)\b'), ' ');
    x = x
        .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');
    final direct = _aliases[x];
    if (direct != null) return direct;
    x = x.replaceAll('ة', 'ه');
    return _aliases[x] ?? x;
  }

  static bool _matches(String pantryItem, String ingredient) {
    final p = normalize(pantryItem);
    final i = normalize(ingredient);
    if (p.isEmpty || i.isEmpty) return false;
    if (p == i) return true;
    final pTokens = p.split(' ').where((x) => x.isNotEmpty).toSet();
    final iTokens = i.split(' ').where((x) => x.isNotEmpty).toSet();
    final shared = pTokens.intersection(iTokens);
    if (shared.isEmpty) return false;
    if (pTokens.length == 1 || iTokens.length == 1) return true;
    return shared.length >= (pTokens.length < iTokens.length ? pTokens.length : iTokens.length);
  }

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

      for (final ingredient in useful) {
        if (normalizedPantry.any((item) => _matches(item, ingredient))) {
          matched.add(ingredient);
        } else {
          missing.add(ingredient);
        }
      }

      if (matched.isEmpty) continue;

      final coverage = useful.isEmpty ? 0.0 : matched.length / useful.length;
      final pantryUse = pantry.isEmpty
          ? 0.0
          : normalizedPantry.where((item) => recipe.ingredients.any((ing) => _matches(item, ing))).length /
              normalizedPantry.length;

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

  @override void initState() { super.initState(); load(); }

  @override void dispose() {
    recipeSearchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('recipes');
    final ing = p.getStringList('pantry');
    final rawHistory = p.getString('recipe_use_count');
    final savedRecent = p.getStringList('recent_recipe_ids') ?? const <String>[];
    if (!mounted) return;
    setState(() {
      if (raw != null) {
        final saved = (jsonDecode(raw) as List).map((e) => Recipe.fromJson(e)).toList();
        final seeds = starterRecipes();
        final seedIds = seeds.map((e) => e.id).toSet();
        final savedById = {for (final r in saved) r.id: r};
        recipes = seeds.map((seed) {
          final old = savedById.remove(seed.id);
          return old == null ? seed : seed.copyWith(favorite: old.favorite);
        }).toList()
          ..addAll(savedById.values.where((r) => !seedIds.contains(r.id)));
      }
      if (ing != null) pantry = ing;
      if (rawHistory != null) {
        final decoded = jsonDecode(rawHistory);
        if (decoded is Map) {
          recipeUseCount = decoded.map(
            (key, value) => MapEntry(key.toString(), value is num ? value.toInt() : 0),
          );
        }
      }
      recentRecipeIds = List<String>.from(savedRecent);
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('recipes', jsonEncode(recipes.map((e) => e.toJson()).toList()));
    await p.setStringList('pantry', pantry);
    await p.setString('recipe_use_count', jsonEncode(recipeUseCount));
    await p.setStringList('recent_recipe_ids', recentRecipeIds);
  }

  List<SmartSuggestion> get smartSuggestions =>
      SmartRecipeEngine.rank(
        pantry,
        recipes,
        history: recipeUseCount,
        recentRecipeIds: recentRecipeIds,
      );

  List<Recipe> get suggestions =>
      smartSuggestions.map((x) => x.recipe).toList();

  List<Recipe> get filteredRecipes => filterRecipes(recipes, recipeQuery, country: selectedCountry);

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'مطبخي الدافي',
    navigatorKey:navigatorKey,theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:rose)),
    home:Directionality(textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(backgroundColor:cream,elevation:0,title:const Text('مطبخي الدافي',style:TextStyle(fontWeight:FontWeight.w900,color:brown)),actions:[
        IconButton(onPressed:showPantry,icon:const Icon(Icons.kitchen_rounded,color:brown))
      ]),
      body:IndexedStack(index:tab,children:[home(), recipesPage(), suggestionsPage(), favoritesPage()]),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),backgroundColor:card,indicatorColor:peach.withValues(alpha: .35),destinations:const[
        NavigationDestination(icon:Icon(Icons.home_rounded),label:'الرئيسية'),
        NavigationDestination(icon:Icon(Icons.menu_book_rounded),label:'وصفاتي'),
        NavigationDestination(icon:Icon(Icons.auto_awesome_rounded),label:'اقترحي لي'),
        NavigationDestination(icon:Icon(Icons.favorite_rounded),label:'المفضلة')
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
      Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 0), child: section('وصفاتي', '\${list.length} ظاهر من \${recipes.length} وصفة')),
      Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 8), child: TextField(
        controller: recipeSearchController, onChanged: (value) => setState(() => recipeQuery = value), textDirection: TextDirection.rtl,
        decoration: InputDecoration(hintText: 'ابحثي باسم الوصفة أو المكوّن…', prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: recipeQuery.isEmpty ? null : IconButton(onPressed: () { recipeSearchController.clear(); setState(() => recipeQuery = ''); }, icon: const Icon(Icons.clear_rounded)),
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
        if (index == 0) return Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFE7F0E5), borderRadius: BorderRadius.circular(24)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome_rounded, color: sage, size: 30), SizedBox(height: 8),
            Text('اقتراحات ذكية من مطبخك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: brown)),
            SizedBox(height: 5), Text('الترتيب بيتعلم من المفضلة والوصفات اللي طبختيها، وبيوضح لك المتوفر والناقص.', style: TextStyle(color: brown, height: 1.4)),
          ]),
        );
        if (list.isEmpty) return empty('لسه مفيش اقتراح مناسب. ضيفي مكونات أكتر أو احفظي وصفات جديدة.');
        return smartSuggestionCard(list[index - 1]);
      },
    );
  }
  Widget favoritesPage() {
    final list = recipes.where((r)=>r.favorite).toList();
    return ListView(padding:const EdgeInsets.all(18),children:[section('المفضلة','الوصفات اللي بتحبي ترجعي لها'),const SizedBox(height:12),...list.map(recipeCard),if(list.isEmpty) empty('اضغطي على القلب جنب أي وصفة عشان تلاقيها هنا بسرعة.')]);
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
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: peach.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: rose, size: 29),
                ),
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
      Container(width:58,height:58,decoration:BoxDecoration(color:peach.withValues(alpha: .25),borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.restaurant_rounded,color:rose,size:29)),
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
      recipeUseCount[r.id] = (recipeUseCount[r.id] ?? 0) + 1;
      recentRecipeIds = [r.id, ...recentRecipeIds.where((id) => id != r.id)].take(12).toList();
    });
    save();
    ScaffoldMessenger.of(navigatorKey.currentState!.context).showSnackBar(
      SnackBar(content: Text('اتسجلت ${r.title} في تاريخ وصفاتك')),
    );
  }

  void toggleFavorite(Recipe r) { setState(()=>recipes=recipes.map((x)=>x.id==r.id?x.copyWith(favorite:!x.favorite):x).toList()); save(); }

  void details(Recipe r) => showModalBottomSheet(context:navigatorKey.currentState!.context,isScrollControlled:true,backgroundColor:cream,builder:(_)=>Directionality(textDirection:TextDirection.rtl,child:DraggableScrollableSheet(expand:false,initialChildSize:.72,builder:(_,c)=>ListView(controller:c,padding:const EdgeInsets.all(22),children:[
    Text(r.title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:brown)),const SizedBox(height:7),
    Text('${r.category} • ${r.time}',style:TextStyle(color:brown.withValues(alpha: .65))),const SizedBox(height:15),
    Text(r.description,style:const TextStyle(color:brown,height:1.5)),
    const SizedBox(height:12),
    FilledButton.icon(
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
    final title=TextEditingController(), ingredients=TextEditingController(), steps=TextEditingController(), time=TextEditingController();
    await showDialog(context:navigatorKey.currentState!.context,builder:(dialogContext)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
      backgroundColor:cream,title:const Text('وصفة جديدة',style:TextStyle(color:brown,fontWeight:FontWeight.w900)),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(title,'اسم الوصفة'),field(ingredients,'المكونات — افصلي بينها بفاصلة'),field(steps,'الطريقة — كل خطوة في سطر'),field(time,'الوقت، مثال: 30 دقيقة')
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إلغاء')),FilledButton(onPressed:(){
        if(title.text.trim().isEmpty)return;
        final r=Recipe(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),category:'بيتي',time:time.text.trim().isEmpty?'غير محدد':time.text.trim(),description:'وصفة من مطبخك.',country:'وصفة شخصية',ingredients:parseIngredients(ingredients.text),steps:parseSteps(steps.text));
        setState(()=>recipes.insert(0,r));save();Navigator.pop(dialogContext);
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
        Wrap(spacing:7,runSpacing:7,children:pantry.map((x)=>InputChip(label:Text(x),onDeleted:(){setState(()=>pantry.remove(x));sheet((){});save();})).toList()),
        const SizedBox(height:10),Row(children:[
          Expanded(child:TextField(controller:c,decoration:InputDecoration(hintText:'مثال: جزر',filled:true,fillColor:Colors.white70,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)))),
          const SizedBox(width:8),IconButton.filled(onPressed:(){final x=c.text.trim();if(x.isNotEmpty&&!pantry.any((item)=>SmartRecipeEngine.normalize(item)==SmartRecipeEngine.normalize(x))){setState(()=>pantry.add(x));sheet((){});c.clear();save();}},icon:const Icon(Icons.add_rounded))
        ])
      ])
    ))));
  }
}
