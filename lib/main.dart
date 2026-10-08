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

void main() => runApp(const CozyMamaApp());

class CozyMamaApp extends StatefulWidget {
  const CozyMamaApp({super.key});
  @override State<CozyMamaApp> createState() => _CozyMamaAppState();
}

class _CozyMamaAppState extends State<CozyMamaApp> {
  int tab = 0;
  List<String> pantry = ['بطاطس','بيض','طماطم','بصل','أرز','دجاج','مكرونة','جبنة'];
  List<Recipe> recipes = [
    const Recipe(id:'1',title:'مكرونة بالصوص الكريمي',category:'غداء',time:'25 دقيقة',description:'وجبة دافئة وسريعة للأيام المزدحمة.',ingredients:['مكرونة','لبن','جبنة','زبدة','ثوم'],steps:['اسلقي المكرونة.','حضّري الصوص بالزبدة والثوم واللبن.','أضيفي الجبنة ثم المكرونة وقدميها دافئة.'],favorite:true),
    const Recipe(id:'2',title:'صينية بطاطس بالدجاج',category:'غداء',time:'50 دقيقة',description:'صينية بيتية مشبعة ومناسبة للعيلة.',ingredients:['بطاطس','دجاج','بصل','طماطم','ثوم'],steps:['قطعي المكونات.','تبّلي الدجاج والخضار.','اخبزي الصينية حتى تنضج وتحمر.']),
    const Recipe(id:'3',title:'أرز بالخضار',category:'سريع',time:'30 دقيقة',description:'اختيار بسيط لما يكون الوقت ضيق.',ingredients:['أرز','جزر','بازلاء','بصل'],steps:['شوّحي البصل والخضار.','أضيفي الأرز والماء.','اتركيه حتى ينضج.'])
  ];

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('recipes');
    final ing = p.getStringList('pantry');
    if (!mounted) return;
    setState(() {
      if (raw != null) recipes = (jsonDecode(raw) as List).map((e) => Recipe.fromJson(e)).toList();
      if (ing != null) pantry = ing;
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('recipes', jsonEncode(recipes.map((e) => e.toJson()).toList()));
    await p.setStringList('pantry', pantry);
  }

  List<Recipe> get suggestions {
    final have = pantry.map((x) => x.toLowerCase()).toSet();
    final scored = recipes.map((r) {
      final score = r.ingredients.where((x) => have.contains(x.toLowerCase())).length;
      return MapEntry(r, score);
    }).where((x) => x.value > 0).toList();
    scored.sort((a,b) => b.value.compareTo(a.value));
    return scored.map((x) => x.key).toList();
  }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'مطبخي الدافي',
    theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:rose)),
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

  Widget recipesPage() => ListView(padding:const EdgeInsets.fromLTRB(18,10,18,90),children:[section('وصفاتي',recipes.length.toString() + ' وصفة محفوظة'),const SizedBox(height:12),...recipes.map(recipeCard)]);
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
        Text(r.category + ' • ' + r.time,style:TextStyle(color:brown.withValues(alpha: .65)))
      ])),
      IconButton(onPressed:()=>toggleFavorite(r),icon:Icon(r.favorite?Icons.favorite_rounded:Icons.favorite_border_rounded,color:r.favorite?rose:brown.withValues(alpha: .5)))
    ])))
  );

  Widget empty(String text) => Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(20)),child:Text(text,style:const TextStyle(color:brown,height:1.5)));

  void toggleFavorite(Recipe r) { setState(()=>recipes=recipes.map((x)=>x.id==r.id?x.copyWith(favorite:!x.favorite):x).toList()); save(); }

  void details(Recipe r) => showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,builder:(_)=>Directionality(textDirection:TextDirection.rtl,child:DraggableScrollableSheet(expand:false,initialChildSize:.72,builder:(_,c)=>ListView(controller:c,padding:const EdgeInsets.all(22),children:[
    Text(r.title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:brown)),const SizedBox(height:7),
    Text(r.category + ' • ' + r.time,style:TextStyle(color:brown.withValues(alpha: .65))),const SizedBox(height:15),
    Text(r.description,style:const TextStyle(color:brown,height:1.5)),const SizedBox(height:22),
    const Text('المكونات',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:brown)),const SizedBox(height:8),
    ...r.ingredients.map((x)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.check_circle_rounded,color:sage),title:Text(x))),
    const SizedBox(height:10),const Text('الطريقة',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:brown)),const SizedBox(height:8),
    ...r.steps.asMap().entries.map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(radius:15,backgroundColor:peach,child:Text((e.key+1).toString(),style:const TextStyle(color:brown))),title:Text(e.value)))
  ]))));

  Future<void> addRecipe() async {
    final title=TextEditingController(), ingredients=TextEditingController(), steps=TextEditingController(), time=TextEditingController();
    await showDialog(context:context,builder:(_)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
      backgroundColor:cream,title:const Text('وصفة جديدة',style:TextStyle(color:brown,fontWeight:FontWeight.w900)),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        field(title,'اسم الوصفة'),field(ingredients,'المكونات — افصلي بينها بفاصلة'),field(steps,'الطريقة — كل خطوة في سطر'),field(time,'الوقت، مثال: 30 دقيقة')
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:(){
        if(title.text.trim().isEmpty)return;
        final r=Recipe(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),category:'بيتي',time:time.text.trim().isEmpty?'غير محدد':time.text.trim(),description:'وصفة من مطبخك.',ingredients:ingredients.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList(),steps:steps.text.split('\\n').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList());
        setState(()=>recipes.insert(0,r));save();Navigator.pop(context);
      },child:const Text('حفظ'))]
    )));
  }

  Widget field(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,maxLines:label.contains('الطريقة')?3:1,decoration:InputDecoration(labelText:label,filled:true,fillColor:Colors.white70,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none))));

  Future<void> showPantry() async {
    final c=TextEditingController();
    await showModalBottomSheet(context:context,backgroundColor:cream,isScrollControlled:true,builder:(_)=>StatefulBuilder(builder:(context,sheet)=>Directionality(textDirection:TextDirection.rtl,child:Padding(
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
