import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const cream = Color(0xFFFFF8EE);
const peach = Color(0xFFF3B39B);
const rose = Color(0xFFD97B70);
const brown = Color(0xFF5B463B);
const sage = Color(0xFF8BAA8B);
const card = Color(0xFFFFFCF7);

class Recipe {
  final String id, title, category, time, description;
  final List<String> ingredients, steps;
  final bool favorite;
  const Recipe({required this.id, required this.title, required this.category, required this.time, required this.description, required this.ingredients, required this.steps, this.favorite = false});
  Recipe copyWith({bool? favorite}) => Recipe(id:id,title:title,category:category,time:time,description:description,ingredients:ingredients,steps:steps,favorite:favorite ?? this.favorite);
  Map<String,dynamic> toJson() => {'id':id,'title':title,'category':category,'time':time,'description':description,'ingredients':ingredients,'steps':steps,'favorite':favorite};
  factory Recipe.fromJson(Map<String,dynamic> j) => Recipe(
    id:j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
    title:j['title'] ?? '', category:j['category'] ?? 'بيتي', time:j['time'] ?? '',
    description:j['description'] ?? '', ingredients:List<String>.from(j['ingredients'] ?? []),
    steps:List<String>.from(j['steps'] ?? []), favorite:j['favorite'] ?? false);
}


class SmartSuggestion {
  final Recipe recipe;
  final List<String> matched;
  final List<String> missing;
  final int score;
  final double coverage;

  const SmartSuggestion({
    required this.recipe,
    required this.matched,
    required this.missing,
    required this.score,
    required this.coverage,
  });
}

class SmartRecipeEngine {
  static const Map<String, String> _aliases = {
    'egg': 'بيض', 'eggs': 'بيض', 'بيضة': 'بيض', 'بيضه': 'بيض',
    'cheese': 'جبنة', 'cheese slices': 'جبنة', 'جبن': 'جبنة', 'جبنه': 'جبنة',
    'milk': 'لبن', 'حليب': 'لبن',
    'chicken': 'دجاج', 'فراخ': 'دجاج', 'فراخك': 'دجاج',
    'potato': 'بطاطس', 'potatoes': 'بطاطس', 'بطاطا': 'بطاطس',
    'tomato': 'طماطم', 'tomatoes': 'طماطم',
    'onion': 'بصل', 'rice': 'أرز', 'رز': 'أرز',
    'pasta': 'مكرونة', 'macaroni': 'مكرونة', 'مكرونه': 'مكرونة',
    'garlic': 'ثوم', 'butter': 'زبدة', 'oil': 'زيت',
    'carrot': 'جزر', 'carrots': 'جزر', 'peas': 'بازلاء',
    'bread': 'عيش', 'خبز': 'عيش',
    'black pepper': 'فلفل أسود', 'pepper': 'فلفل', 'salt': 'ملح',
  };

  static const Set<String> _staples = {'ملح', 'فلفل', 'فلفل أسود', 'زيت', 'ماء'};

  static String normalize(String value) {
    var x = value.toLowerCase().trim();
    x = x
        .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    x = x.replaceAll(RegExp(r'\s+'), ' ');
    return _aliases[x] ?? x;
  }

  static bool _matches(String pantryItem, String ingredient) {
    final p = normalize(pantryItem);
    final i = normalize(ingredient);
    if (p == i) return true;
    if (p.contains(i) || i.contains(p)) return true;
    final pTokens = p.split(' ').toSet();
    final iTokens = i.split(' ').toSet();
    if (pTokens.intersection(iTokens).isNotEmpty && pTokens.length == 1) return true;
    return false;
  }

  static List<SmartSuggestion> rank(List<String> pantry, List<Recipe> recipes) {
    final results = <SmartSuggestion>[];
    for (final recipe in recipes) {
      final matched = <String>[];
      final missing = <String>[];
      for (final ingredient in recipe.ingredients) {
        if (_staples.contains(normalize(ingredient))) continue;
        if (pantry.any((item) => _matches(item, ingredient))) {
          matched.add(ingredient);
        } else {
          missing.add(ingredient);
        }
      }
      if (matched.isEmpty) continue;
      final usefulCount = matched.length + missing.length;
      final coverage = usefulCount == 0 ? 0.0 : matched.length / usefulCount;
      final score = matched.length * 30 + (coverage * 25).round() - (missing.length * 2);
      results.add(SmartSuggestion(
        recipe: recipe,
        matched: matched,
        missing: missing,
        score: score,
        coverage: coverage,
      ));
    }
    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      final coverage = b.coverage.compareTo(a.coverage);
      if (coverage != 0) return coverage;
      return a.recipe.time.compareTo(b.recipe.time);
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



List<Recipe> starterRecipes() => const [
  Recipe(
    id:'1', title:'مكرونة بالصوص الكريمي', category:'غداء', time:'25 دقيقة',
    description:'وجبة دافئة وكريمية بطعم بيتي بسيط، وتنجح بسهولة حتى في الأيام المزدحمة.',
    ingredients:['مكرونة','لبن','جبنة','زبدة','ثوم','فلفل أسود'],
    steps:[
      'جهزي المكونات وقطعي الثوم ناعمًا وابشري الجبنة.',
      'اغلي الماء وأضيفي رشة ملح، ثم اسلقي المكرونة حتى تنضج مع بقاء قوامها متماسكًا.',
      'احتفظي بنصف كوب من ماء السلق قبل تصفية المكرونة.',
      'في طاسة واسعة ذوّبي الزبدة ثم شوّحي الثوم 30 إلى 45 ثانية دون أن يتحمر.',
      'أضيفي اللبن تدريجيًا مع التقليب، ثم خففي النار حتى يسخن دون غليان قوي.',
      'أضيفي الجبنة على دفعات وقلبي حتى تذوب ويتجانس الصوص.',
      'أضيفي المكرونة وقلبي، ثم أضيفي قليلًا من ماء السلق إذا احتاج الصوص أن يصبح أخف.',
      'تبّلي بالفلفل الأسود واضبطي الملح وقدميها فورًا.',
    ],
    favorite:true,
  ),
  Recipe(
    id:'2', title:'صينية بطاطس بالدجاج', category:'غداء', time:'50 دقيقة',
    description:'صينية بيتية كاملة بالبطاطس والدجاج والبصل والطماطم.',
    ingredients:['بطاطس','دجاج','بصل','طماطم','ثوم','زيت','ملح','فلفل أسود'],
    steps:[
      'سخني الفرن مسبقًا على 200 مئوية.',
      'قطعي البطاطس شرائح متوسطة والبصل والطماطم، وقطعي الدجاج إلى قطع متقاربة الحجم.',
      'اخلطي الدجاج مع الثوم والملح والفلفل وقليل من الزيت حتى تتوزع التتبيلة.',
      'ادهني الصينية بقليل من الزيت ورتبي البطاطس في القاع.',
      'وزعي البصل والطماطم ثم رتبي الدجاج بالتساوي.',
      'أضيفي نصف كوب ماء حول أطراف الصينية للمساعدة على استواء البطاطس.',
      'غطي الصينية بالفويل واخبزيها حوالي 30 دقيقة.',
      'ارفعي الفويل وأعيديها للفرن حتى ينضج الدجاج وتأخذ الصينية لونًا ذهبيًا.',
      'اتركيها 5 دقائق قبل التقديم.',
    ],
  ),
  Recipe(
    id:'3', title:'أرز بالخضار', category:'سريع', time:'30 دقيقة',
    description:'أرز خفيف بالخضار مناسب لوجبة سريعة من الموجود في البيت.',
    ingredients:['أرز','جزر','بازلاء','بصل','زيت','ملح'],
    steps:[
      'اغسلي الأرز جيدًا وصفيه.',
      'قطعي البصل مكعبات صغيرة والجزر قطعًا متقاربة الحجم.',
      'سخني الزيت وشوّحي البصل حتى يلين.',
      'أضيفي الجزر والبازلاء وقلبي 2 إلى 3 دقائق.',
      'أضيفي الأرز وقلبيه دقيقة حتى تتغلف الحبات بالزيت.',
      'أضيفي الماء الساخن والملح واتركي الخليط حتى يبدأ في الغليان.',
      'خففي النار لأقل درجة وغطي الحلة جيدًا.',
      'اتركي الأرز حتى يمتص الماء وينضج، ثم أطفئي النار واتركيه مغطى 5 دقائق.',
      'فككي الأرز بالشوكة وقدميه ساخنًا.',
    ],
  ),
  Recipe(
    id:'4', title:'بيض بالجبنة والطماطم', category:'سريع', time:'15 دقيقة',
    description:'وجبة سريعة عندما يكون عندك بيض وجبنة وتريدين استخدام مكونات بسيطة.',
    ingredients:['بيض','جبنة','طماطم','بصل','زبدة','ملح','فلفل أسود'],
    steps:[
      'قطعي البصل والطماطم وابشري الجبنة أو قطعيها شرائح رفيعة.',
      'اخفقي البيض مع رشة ملح وفلفل حتى يتجانس.',
      'سخني طاسة غير لاصقة وأضيفي الزبدة.',
      'شوّحي البصل حتى يلين ثم أضيفي الطماطم حتى تطلق قليلًا من عصارتها.',
      'خففي النار واسكبي البيض واتركيه يبدأ في التماسك من الأطراف.',
      'وزعي الجبنة فوق البيض قبل أن يجف تمامًا.',
      'حركي بهدوء من الأطراف للداخل حتى ينضج دون أن يصبح جافًا.',
      'أطفئي النار عندما يبقى السطح طريًا قليلًا.',
      'قدميه فورًا مع العيش أو أي مكوّن متوفر.',
    ],
  ),
  Recipe(
    id:'5', title:'عجة البطاطس بالجبنة', category:'سريع', time:'25 دقيقة',
    description:'عجة طرية تجمع البطاطس والبيض والجبنة في وجبة اقتصادية.',
    ingredients:['بطاطس','بيض','جبنة','بصل','زيت','ملح','فلفل أسود'],
    steps:[
      'قشري البطاطس وقطعيها مكعبات صغيرة.',
      'اسلقي البطاطس 6 إلى 8 دقائق ثم صفيها جيدًا.',
      'اخفقي البيض مع الملح والفلفل وأضيفي الجبنة.',
      'سخني الزيت وشوّحي البصل حتى يلين.',
      'أضيفي البطاطس وحركيها حتى تأخذ لونًا خفيفًا.',
      'اسكبي خليط البيض ووزعيه فوق البطاطس.',
      'خففي النار جدًا وغطي الطاسة حتى يتماسك القاع ويبدأ الوجه في النضج.',
      'اقسمي العجة أو اقلبيها بحذر إذا أصبحت متماسكة.',
      'اطهيها دقيقة إضافية ثم قدميها دافئة.',
    ],
  ),
  Recipe(
    id:'6', title:'شكشوكة بالجبنة', category:'فطار', time:'20 دقيقة',
    description:'شكشوكة بطابع بيتي مع طماطم وبصل وثوم ولمسة جبنة.',
    ingredients:['بيض','طماطم','بصل','ثوم','جبنة','زيت','ملح','فلفل أسود'],
    steps:[
      'فرمي البصل والثوم وقطعي الطماطم قطعًا صغيرة.',
      'سخني الزيت وشوّحي البصل حتى يصبح شفافًا.',
      'أضيفي الثوم وقلبيه نصف دقيقة فقط.',
      'أضيفي الطماطم والملح والفلفل واتركيها حتى تصبح صوصًا كثيفًا.',
      'اعملي تجاويف صغيرة في الصوص بظهر الملعقة.',
      'اكسري بيضة في كل تجويف وغطي الطاسة حتى يتماسك البياض.',
      'وزعي الجبنة فوق البيض في آخر دقيقتين حتى تذوب جزئيًا.',
      'تابعي التسوية حتى يصل البيض للقوام الذي تفضلينه.',
      'قدميها ساخنة مباشرة.',
    ],
  ),
  Recipe(
    id:'7', title:'مكرونة بالبيض والجبنة', category:'سريع', time:'20 دقيقة',
    description:'وجبة سريعة جدًا تعتمد على المكرونة والبيض والجبنة.',
    ingredients:['مكرونة','بيض','جبنة','زبدة','فلفل أسود'],
    steps:[
      'اسلقي المكرونة حتى تصبح متماسكة واحتفظي بقليل من ماء السلق.',
      'اخفقي البيض مع الجبنة والفلفل الأسود.',
      'صفي المكرونة مع الاحتفاظ بنصف كوب من ماء السلق.',
      'أعيدي المكرونة للطاسة مع الزبدة وقلبي دقيقة.',
      'ارفعي الطاسة عن النار وأضيفي خليط البيض بسرعة مع التقليب.',
      'أضيفي ماء السلق تدريجيًا حتى يصبح الخليط كريميًا.',
      'أعيدي الطاسة لنار منخفضة جدًا لبضع ثوانٍ فقط عند الحاجة.',
      'تذوقي واضبطي الملح ثم قدميها فورًا.',
    ],
  ),
  Recipe(
    id:'8', title:'صينية بطاطس بالجبنة', category:'عشاء', time:'35 دقيقة',
    description:'بطاطس طرية بوجه جبنة ذائب مناسبة للعشاء.',
    ingredients:['بطاطس','جبنة','لبن','زبدة','ثوم','ملح','فلفل أسود'],
    steps:[
      'سخني الفرن على 200 مئوية وادهني صينية صغيرة بالزبدة.',
      'قشري البطاطس وقطعيها شرائح رفيعة ومتقاربة السمك.',
      'رتبي نصف البطاطس ورشي قليلًا من الملح والفلفل.',
      'وزعي جزءًا من الجبنة والثوم ثم أضيفي باقي البطاطس.',
      'اسكبي اللبن بين الطبقات وأضيفي باقي الجبنة على الوجه.',
      'وزعي قطعًا صغيرة من الزبدة وغطي الصينية.',
      'اخبزيها حوالي 25 دقيقة حتى تبدأ البطاطس في الطراوة.',
      'ارفعي الغطاء واتركيها 8 إلى 10 دقائق حتى يتحمر الوجه.',
      'اختبري البطاطس بطرف سكين واتركيها 5 دقائق قبل التقديم.',
    ],
  ),
  Recipe(
    id:'9', title:'أرز بالدجاج والخضار', category:'غداء', time:'45 دقيقة',
    description:'وجبة واحدة تجمع الدجاج والأرز والخضار في حلة واحدة.',
    ingredients:['أرز','دجاج','بصل','جزر','بازلاء','طماطم','زيت','ملح','فلفل أسود'],
    steps:[
      'قطعي الدجاج إلى قطع متساوية وقطعي البصل والجزر والطماطم.',
      'اغسلي الأرز وصفيه جيدًا.',
      'سخني الزيت وحمري الدجاج على دفعات حتى يتغير لونه من الخارج.',
      'أضيفي البصل ثم الجزر والبازلاء وقلبي حتى تلين.',
      'أضيفي الطماطم وقلبي حتى تختلط عصارتها بالمكونات.',
      'أعيدي الدجاج وأضيفي الأرز والملح والفلفل وقلبي دقيقة.',
      'أضيفي الماء الساخن واتركي الخليط حتى يبدأ في الغليان.',
      'خففي النار جدًا وغطي الحلة حتى ينضج الأرز والدجاج بالكامل.',
      'أطفئي النار واتركيها 5 دقائق ثم فككي الأرز بالشوكة وقدميه.',
    ],
  ),
  Recipe(
    id:'10', title:'توست بالبيض والجبنة', category:'فطار', time:'10 دقائق',
    description:'أسرع اختيار للفطار عند توفر البيض والجبنة والعيش.',
    ingredients:['بيض','جبنة','عيش','طماطم','زبدة','فلفل أسود'],
    steps:[
      'اخفقي البيض مع الفلفل الأسود ورشة صغيرة من الملح.',
      'سخني طاسة وادهنيها بقليل من الزبدة.',
      'غمسي الخبز في خليط البيض من الجانبين بسرعة.',
      'ضعي الخبز في الطاسة وحمريه من الجانبين.',
      'ضعي الجبنة فوق الخبز الساخن واتركيها دقيقة حتى تبدأ في الذوبان.',
      'أضيفي شرائح الطماطم حسب الرغبة.',
      'أغلقي الساندويتش أو قدميه مفتوحًا وهو دافئ.',
    ],
  ),
];

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

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('recipes');
    final ing = p.getStringList('pantry');
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
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('recipes', jsonEncode(recipes.map((e) => e.toJson()).toList()));
    await p.setStringList('pantry', pantry);
  }

  List<Recipe> get suggestions =>
      SmartRecipeEngine.rank(pantry, recipes).map((x) => x.recipe).toList();

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
    final picks = suggestions.take(3).toList();
    return ListView(padding:const EdgeInsets.fromLTRB(18,8,18,30),children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFFE7D8),Color(0xFFF8D7D0)]),borderRadius:BorderRadius.circular(28)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('أهلاً يا ماما',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:brown)),
        SizedBox(height:8),Text('خلّي المطبخ أهدى شوية… قوليلي إيه موجود عندك وأنا أساعدك تختاري وجبة.',style:TextStyle(fontSize:15,height:1.5,color:brown))
      ])),
      const SizedBox(height:20), section('ماذا نطبخ اليوم؟','حسب المكونات اللي عندك'),
      const SizedBox(height:10),
      if(picks.isEmpty) empty('ضيفي مكوناتك عشان أقدر أقترح لك وجبات.') else ...picks.map(recipeCard),
      const SizedBox(height:12), section('وصفاتك','كل وصفات البيت في مكان واحد'),
      const SizedBox(height:10), ...recipes.take(2).map(recipeCard)
    ]);
  }

  Widget recipesPage() => ListView(padding:const EdgeInsets.fromLTRB(18,10,18,90),children:[section('وصفاتي','${recipes.length} وصفة محفوظة'),const SizedBox(height:12),...recipes.map(recipeCard)]);
  Widget suggestionsPage() => ListView(padding:const EdgeInsets.all(18),children:[
    Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:const Color(0xFFE7F0E5),borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.auto_awesome_rounded,color:sage,size:30),SizedBox(height:8),
      Text('اقتراحات من مطبخك',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:brown)),
      SizedBox(height:5),Text('التطبيق يقارن مكوناتك بالوصفات المحفوظة ويرتب لك الأقرب أولاً.',style:TextStyle(color:brown,height:1.4))
    ])),
    const SizedBox(height:18),...suggestions.map(recipeCard),
    if(suggestions.isEmpty) empty('لسه مفيش اقتراح مناسب. ضيفي مكونات أكتر أو احفظي وصفات جديدة.')
  ]);
  Widget favoritesPage() {
    final list = recipes.where((r)=>r.favorite).toList();
    return ListView(padding:const EdgeInsets.all(18),children:[section('المفضلة','الوصفات اللي بتحبي ترجعي لها'),const SizedBox(height:12),...list.map(recipeCard),if(list.isEmpty) empty('اضغطي على القلب جنب أي وصفة عشان تلاقيها هنا بسرعة.')]);
  }

  Widget section(String title,String sub) => Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:brown)),const SizedBox(height:3),Text(sub,style:TextStyle(color:brown.withValues(alpha: .65)))])),
    const Icon(Icons.restaurant_menu_rounded,color:rose)
  ]);

  Widget recipeCard(Recipe r) => Card(color:card,elevation:0,margin:const EdgeInsets.only(bottom:12),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:InkWell(
    borderRadius:BorderRadius.circular(22),onTap:()=>details(r),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
      Container(width:58,height:58,decoration:BoxDecoration(color:peach.withValues(alpha: .25),borderRadius:BorderRadius.circular(18)),child:const Icon(Icons.restaurant_rounded,color:rose,size:29)),
      const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(r.title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:brown)),const SizedBox(height:5),
        Text('${r.category} • ${r.time}',style:TextStyle(color:brown.withValues(alpha: .65)))
      ])),
      IconButton(onPressed:()=>toggleFavorite(r),icon:Icon(r.favorite?Icons.favorite_rounded:Icons.favorite_border_rounded,color:r.favorite?rose:brown.withValues(alpha: .5)))
    ])))
  );

  Widget empty(String text) => Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(20)),child:Text(text,style:const TextStyle(color:brown,height:1.5)));

  void toggleFavorite(Recipe r) { setState(()=>recipes=recipes.map((x)=>x.id==r.id?x.copyWith(favorite:!x.favorite):x).toList()); save(); }

  void details(Recipe r) => showModalBottomSheet(context:navigatorKey.currentState!.context,isScrollControlled:true,backgroundColor:cream,builder:(_)=>Directionality(textDirection:TextDirection.rtl,child:DraggableScrollableSheet(expand:false,initialChildSize:.72,builder:(_,c)=>ListView(controller:c,padding:const EdgeInsets.all(22),children:[
    Text(r.title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:brown)),const SizedBox(height:7),
    Text('${r.category} • ${r.time}',style:TextStyle(color:brown.withValues(alpha: .65))),const SizedBox(height:15),
    Text(r.description,style:const TextStyle(color:brown,height:1.5)),const SizedBox(height:22),
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
        final r=Recipe(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),category:'بيتي',time:time.text.trim().isEmpty?'غير محدد':time.text.trim(),description:'وصفة من مطبخك.',ingredients:parseIngredients(ingredients.text),steps:parseSteps(steps.text));
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
          const SizedBox(width:8),IconButton.filled(onPressed:(){final x=c.text.trim();if(x.isNotEmpty&&!pantry.contains(x)){setState(()=>pantry.add(x));sheet((){});c.clear();save();}},icon:const Icon(Icons.add_rounded))
        ])
      ])
    ))));
  }
}
