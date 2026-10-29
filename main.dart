import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fl_chart/fl_chart.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }
  static Future _schedule(int id, int h, int m, String t, String b) async {
    final now = tz.TZDateTime.now(tz.local);
    var time = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if(time.isBefore(now)) time = time.add(const Duration(days:1));
    await _plugin.zonedSchedule(id, t, b, time,
      const NotificationDetails(android: AndroidNotificationDetails('habit','Habits',importance: Importance.high)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time);
  }
  static Future setupAllReminders() async {
    await _plugin.cancelAll();
    await _schedule(1, 9, 0, "💧 Water", "Time to hydrate!");
    await _schedule(2, 15, 0, "💧 Water", "Time to hydrate! - second reminder");
    await _schedule(3, 21, 0, "💧 Water", "Time to hydrate! - last for today");
    await _schedule(4, 15, 5, "💪 Workout", "Workout time - let's go! (3:05 PM)");
    await _schedule(5, 18, 0, "📚 Reading", "Reading time");
    await _schedule(6, 22, 0, "🌙 Sleep", "Wind down for sleep");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('data');
  await Hive.openBox('settings');
  var settings = Hive.box('settings');
  if(settings.get('customCats')==null) settings.put('customCats', []);
  await NotificationService.init();
  await NotificationService.setupAllReminders();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner:false,
      theme: ThemeData(scaffoldBackgroundColor:const Color(0xFFF8F7FF), useMaterial3:true),
      home: const Home());
  }
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState(); }

class _HomeState extends State<Home> {
  DateTime selected = DateTime.now();
  final box = Hive.box('data');
  final settings = Hive.box('settings');
  int tab = 0;
  String keyFor(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  Map getDayData(DateTime d) => Map.from(box.get(keyFor(d), defaultValue: {}) as Map);
  List get customCats => settings.get('customCats', defaultValue: []) as List;

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation:0, title: const Text("Pastel Life Tracker", style:TextStyle(fontWeight:FontWeight.bold))),
      body: SafeArea(child: tab==0 ? buildToday() : buildStats()),
      bottomNavigationBar: BottomNavigationBar(currentIndex: tab, onTap:(i)=>setState(()=>tab=i), selectedItemColor: const Color(0xFF9A7DFF),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'), BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats')]),
      floatingActionButton: tab==0 ? FloatingActionButton.extended(onPressed: _showAddCustomDialog, backgroundColor: const Color(0xFFE2D1F9), icon: const Icon(Icons.add), label: const Text("Add Category")) : null,
    );
  }

  Widget buildToday() {
    final data = getDayData(selected);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color:Colors.white, borderRadius:BorderRadius.circular(20)),
        child: Column(children: [
          Text(DateFormat('MMMM yyyy').format(selected), style: const TextStyle(fontWeight: FontWeight.bold, fontSize:18)),
          const SizedBox(height:12),
          SizedBox(height:65, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount:14, itemBuilder:(c,i){
            final d = DateTime.now().subtract(const Duration(days:7)).add(Duration(days:i));
            final isSel = DateFormat('yyyy-MM-dd').format(d)==DateFormat('yyyy-MM-dd').format(selected);
            return GestureDetector(onTap:()=>setState(()=>selected=d),
              child: Container(margin: const EdgeInsets.symmetric(horizontal:6), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color:isSel? const Color(0xFFE2D1F9): Colors.white, borderRadius:BorderRadius.circular(16), border:Border.all(color:const Color(0xFFF0F0F0))),
                child: Column(children:[Text(DateFormat('E').format(d).substring(0,3), style:TextStyle(fontSize:11, color:isSel? Colors.black: Colors.grey)), Text("${d.day}", style: TextStyle(fontWeight:isSel? FontWeight.bold: FontWeight.normal))])));
          }))
        ])),
      const SizedBox(height:16),
      GridView.count(crossAxisCount:2, shrinkWrap:true, physics: const NeverScrollableScrollPhysics(), childAspectRatio:1.15, children:[
        _card("Water", "${data['water']??0} / ${data['waterTarget']??8}", const Color(0xFFC9D9FF), Icons.water_drop, ()=>_editNumber("Water", "water", "waterTarget")),
        _card("Food", "${(data['food'] as List?)?.length??0}/6", const Color(0xFFFFF2B2), Icons.restaurant, ()=>_editFood()),
        _card("Sleep", "${data['sleep']??0} / ${data['sleepTarget']??8}h", const Color(0xFFE2D1F9), Icons.bedtime, ()=>_editNumber("Sleep","sleep","sleepTarget")),
        _card("Workout", "${(data['workout'] as List?)?.length??0} muscles", const Color(0xFFC6F5D9), Icons.fitness_center, ()=>_editWorkout()),
        _card("Meditation", "${data['meditation']??0} / ${data['medTarget']??20}m", const Color(0xFFFFDAB9), Icons.self_improvement, ()=>_editNumber("Meditation","meditation","medTarget")),
        _card("Reading", "${data['reading']??0} / ${data['readTarget']??1}h", const Color(0xFFFFC8D2), Icons.menu_book, ()=>_editNumber("Reading","reading","readTarget")),
        ...customCats.map((cat){
          final name = cat['name']; final key = 'custom_$name';
          return _card(name, "${data[key]??0} / ${cat['target']}", Color(cat['color']), Icons.star, ()=>_editNumber(name, key, null), isCustom:true, onLongPress:()=>_deleteCustom(name));
        }).toList(),
      ]),
    ]);
  }

  Widget buildStats(){
    return ListView(padding: const EdgeInsets.all(16), children:[
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color:Colors.white, borderRadius:BorderRadius.circular(20)),
        child: const Column(children:[ Text("Weekly Progress", style:TextStyle(fontWeight:FontWeight.bold)), SizedBox(height:16), SizedBox(height:120, child: WeeklyChart())])),
    ]);
  }

  Widget _card(String title, String sub, Color color, IconData icon, VoidCallback onTap, {bool isCustom=false, VoidCallback? onLongPress}){
    return GestureDetector(onTap:onTap, onLongPress:onLongPress, child: Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color:color, borderRadius:BorderRadius.circular(20)),
      child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[ Icon(icon, size:28), const SizedBox(height:6), Text(title, style:const TextStyle(fontWeight:FontWeight.bold, fontSize:13)), Text(sub, style:const TextStyle(fontSize:10), textAlign:TextAlign.center), if(isCustom) const Text("long-press to delete", style:TextStyle(fontSize:8)) ])));
  }

  void _editNumber(String title, String key, String? targetKey) {
    final ctrl = TextEditingController(); final targetCtrl = TextEditingController();
    showDialog(context: context, builder:(c)=>AlertDialog(title:Text(title), content:Column(mainAxisSize:MainAxisSize.min, children:[ TextField(controller:ctrl, keyboardType:TextInputType.number, decoration: InputDecoration(labelText: "Today's $title")), if(targetKey!=null) TextField(controller:targetCtrl, keyboardType:TextInputType.number, decoration: const InputDecoration(labelText:"Target")) ]), actions:[TextButton(onPressed:(){ final d=getDayData(this.selected); d[key]=double.tryParse(ctrl.text)??0; if(targetKey!=null && targetCtrl.text.isNotEmpty) d[targetKey]=double.tryParse(targetCtrl.text); box.put(keyFor(this.selected), d); setState((){}); Navigator.pop(c);}, child: const Text("Save"))]));
  }
  
  void _editFood(){
    final options = ["Healthy Carbs","Fibers","Protein","Micronutrients","No Sugar","No Junk Food"];
    List selectedList = List.from((getDayData(selected)['food']??[]) as List);
    showDialog(context: context, builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(title: const Text("Food Today"), content: Column(mainAxisSize:MainAxisSize.min, children: options.map((o)=>CheckboxListTile(dense:true, title:Text(o, style:const TextStyle(fontSize:13)), value:selectedList.contains(o), onChanged:(v){ setD((){ v! ? selectedList.add(o) : selectedList.remove(o);});})).toList(),), actions:[TextButton(onPressed:(){ final d=getDayData(this.selected); d['food']=selectedList; box.put(keyFor(this.selected), d); setState((){}); Navigator.pop(c);}, child: const Text("Save"))])));
  }
  
  void _editWorkout(){
    final options = ["Rest Day","Arms","Biceps","Triceps","Shoulder","Chest","Abs","Back","Legs","Glutes"];
    List selectedList = List.from((getDayData(selected)['workout']??[]) as List);
    showDialog(context: context, builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(title: const Text("Workout Today"), content: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min, children: options.map((o)=>CheckboxListTile(dense:true, title:Text(o, style:const TextStyle(fontSize:13)), value:selectedList.contains(o), onChanged:(v){ setD((){ v! ? selectedList.add(o) : selectedList.remove(o);});})).toList())), actions:[TextButton(onPressed:(){ final d=getDayData(this.selected); d['workout']=selectedList; box.put(keyFor(this.selected), d); setState((){}); Navigator.pop(c);}, child: const Text("Save"))])));
  }

  void _showAddCustomDialog(){
    final nameCtrl = TextEditingController(); final targetCtrl = TextEditingController(text:"5");
    Color picked = const Color(0xFFE2D1F9);
    final colors = [0xFFC9D9FF, 0xFFFFF2B2, 0xFFE2D1F9, 0xFFC6F5D9, 0xFFFFDAB9, 0xFFFFC8D2].map((e)=>Color(e)).toList();
    showDialog(context: context, builder:(c)=>StatefulBuilder(builder:(ctx,setD){
      return AlertDialog(title: const Text("Add Custom Category"), content: Column(mainAxisSize:MainAxisSize.min, children:[
        TextField(controller:nameCtrl, decoration: const InputDecoration(labelText:"Name (e.g., Study)")),
        TextField(controller:targetCtrl, keyboardType:TextInputType.number, decoration: const InputDecoration(labelText:"Daily Target")),
        const SizedBox(height:12), const Text("Pick color"), Wrap(children: colors.map((co)=>GestureDetector(onTap:(){ setD(()=>picked=co);}, child: Container(margin: const EdgeInsets.all(4), width:30, height:30, decoration: BoxDecoration(color:co, shape:BoxShape.circle, border:Border.all(width:picked==co?3:0))))).toList()),
      ]), actions:[TextButton(onPressed:(){
        if(nameCtrl.text.isEmpty) return;
        final list = List.from(customCats);
        list.add({'name':nameCtrl.text, 'target':targetCtrl.text, 'color':picked.value});
        settings.put('customCats', list);
        setState((){}); Navigator.pop(c);
      }, child: const Text("Add"))]);
    }));
  }

  void _deleteCustom(String name){
    showDialog(context: context, builder:(c)=>AlertDialog(title:Text("Delete $name?"), actions:[TextButton(onPressed:(){ final list = List.from(customCats); list.removeWhere((e)=>e['name']==name); settings.put('customCats', list); setState((){}); Navigator.pop(c);}, child: const Text("Delete"))]));
  }
}

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key});
  @override Widget build(BuildContext context) {
    return BarChart(BarChartData(gridData: const FlGridData(show:false), borderData: FlBorderData(show:false), titlesData: FlTitlesData(show:true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, getTitlesWidget:(v,_)=>Text(['M','T','W','T','F','S','S'][v.toInt()], style:const TextStyle(fontSize:10))))), barGroups: List.generate(7, (i)=>BarChartGroupData(x:i, barRods:[BarChartRodData(toY:(3+i%3*2).toDouble(), width:12, color: const Color(0xFFC9D9FF), borderRadius:BorderRadius.circular(4))]))));
  }
}
