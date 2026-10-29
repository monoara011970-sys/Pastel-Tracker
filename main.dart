import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:table_calendar/table_calendar.dart';

class NotifService {
  static final _p = FlutterLocalNotificationsPlugin();
  static Future init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _p.initialize(const InitializationSettings(android: android));
  }
  static Future sched(int id, int h, int m, String t, String b) async {
    final now = tz.TZDateTime.now(tz.local);
    var time = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (time.isBefore(now)) time = time.add(const Duration(days: 1));
    await _p.zonedSchedule(
      id, t, b, time,
      const NotificationDetails(android: AndroidNotificationDetails('pastel_v2', 'Pastel Reminders', importance: Importance.max)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  static Future scheduleAll() async {
    await sched(1, 9, 0, 'Water 💧', '9 AM - Time to log water!');
    await sched(2, 15, 0, 'Water 💧', '3 PM - Stay hydrated!');
    await sched(3, 21, 0, 'Water 💧', '9 PM - Log your water!');
    await sched(4, 17, 0, 'Workout 💪', '5 PM - Workout time!');
    await sched(5, 18, 0, 'Reading 📚', '6 PM - Reading reminder!');
    await sched(6, 22, 0, 'Sleep 🌙', '10 PM - Log sleep & wind down!');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('daily');
  await Hive.openBox('targets');
  await Hive.openBox('custom_cats');
  tz.initializeTimeZones();
  await NotifService.init();
  await NotifService.scheduleAll();
  runApp(const PastelApp());
}

class PastelApp extends StatelessWidget {
  const PastelApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB5C2), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFFFF8F9),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home> {
  int idx=0;
  final pages=[const TodayFullPage(), const CalendarPage(), const StatsFullPage(), const SettingsFullPage()];
  @override Widget build(BuildContext context){
    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected: (i)=>setState(()=>idx=i), destinations: const [
        NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Today'),
        NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
        NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Progress'),
        NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
      ]),
    );
  }
}

String todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());
Map getDay(String k){ return Hive.box('daily').get(k, defaultValue: {}) as Map; }
void saveDay(String k, Map m){ Hive.box('daily').put(k, m); }
double getTarget(String cat, double def){ return (Hive.box('targets').get(cat, defaultValue: def) as num).toDouble(); }

class TodayFullPage extends StatefulWidget { const TodayFullPage({super.key}); @override State<TodayFullPage> createState()=>_TodayFullPageState();}
class _TodayFullPageState extends State<TodayFullPage> {
  String date = todayKey();
  @override Widget build(BuildContext context){
    final day = getDay(date);
    final customKeys = Hive.box('custom_cats').keys.toList();
    return SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
      Text('Pastel Tracker 🌸', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      Text(DateFormat('EEEE, MMM d').format(DateTime.parse(date)), style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 16),
      _sleepCard(day), const SizedBox(height: 14),
      _waterCard(day), const SizedBox(height: 14),
      _foodCard(day), const SizedBox(height: 14),
      _workoutCard(day), const SizedBox(height: 14),
      _meditationCard(day), const SizedBox(height: 14),
      _readingCard(day), const SizedBox(height: 14),
      // CUSTOM - COMPLETELY SEPARATE
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFFE0E8FF), borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('✨ Other Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const Text('Your own habits - totally separate', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          if(customKeys.isEmpty) const Text('No custom yet. Tap button below to add.'),
          ...customKeys.map((c){
            double v = (day['custom_$c'] ?? 0).toDouble();
            return Card(child: ListTile(
              title: Text(c.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Today: $v'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.remove), onPressed: ()=>_updateCustom(c.toString(), v-1)),
                IconButton(icon: const Icon(Icons.add), onPressed: ()=>_updateCustom(c.toString(), v+1)),
                IconButton(icon: const Icon(Icons.delete_outline, size:18), onPressed: (){ Hive.box('custom_cats').delete(c); setState((){}); }),
              ]),
            ));
          }),
        ]),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(onPressed: _addCategory, icon: const Icon(Icons.add), label: const Text('Add New Category')),
      const SizedBox(height: 30),
    ]));
  }

  Widget _pastelBox({required Color color, required Widget child}){
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)), child: child);
  }
  Widget _sleepCard(Map day){
    double target = getTarget('Sleep', 8);
    double slept = (day['sleep'] ?? 0).toDouble();
    return _pastelBox(color: const Color(0xFFE8E0FF), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('🌙 Sleep', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        InkWell(onTap: ()=>_editTarget('Sleep', target), child: Text('Target: ${target}h ✏️', style: const TextStyle(color: Colors.grey))),
      ]),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: (slept/target).clamp(0,1), minHeight: 10, borderRadius: BorderRadius.circular(10)),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: Text('${slept.toStringAsFixed(1)}h / ${target}h')), _smallBtn('-0.5', ()=>_updateSleep(slept-0.5)), const SizedBox(width: 6), _smallBtn('+0.5', ()=>_updateSleep(slept+0.5))]),
    ]));
  }
  Widget _waterCard(Map day){
    double target = getTarget('Water', 2000);
    double drank = (day['water'] ?? 0).toDouble();
    return _pastelBox(color: const Color(0xFFD6F0FF), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('💧 Water', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        InkWell(onTap: ()=>_editTarget('Water', target), child: Text('Target: ${target.toInt()} ml ✏️', style: const TextStyle(color: Colors.grey))),
      ]),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: (drank/target).clamp(0,1), minHeight: 10, borderRadius: BorderRadius.circular(10), color: Colors.blueAccent),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: Text('${drank.toInt()} / ${target.toInt()} ml')), _smallBtn('250', ()=>_updateWater(drank+250)), const SizedBox(width: 6), _smallBtn('500', ()=>_updateWater(drank+500))]),
    ]));
  }
  Widget _foodCard(Map day){
    Map food = day['food'] ?? {};
    return _pastelBox(color: const Color(0xFFFFF0D6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('🍎 Food', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 10),
      ...['Healthy Carbs','Fibers','Protein','Micronutrients'].map((s)=> CheckboxListTile(
        contentPadding: EdgeInsets.zero, dense: true, title: Text(s), value: food[s] ?? false,
        onChanged: (v){ food[s]=v; _saveFood(food); },
      )),
      const Divider(),
      SwitchListTile(title: const Text('No Sugar'), value: food['noSugar'] ?? false, onChanged: (v){ food['noSugar']=v; _saveFood(food); }),
      SwitchListTile(title: const Text('No Junk Food'), value: food['noJunk'] ?? false, onChanged: (v){ food['noJunk']=v; _saveFood(food); }),
    ]));
  }
  Widget _workoutCard(Map day){
    Map w = day['workout'] ?? {};
    List<String> parts = ['Rest Day','Arms','Biceps','Triceps','Shoulder','Chest','Abs','Back','Legs','Glutes'];
    return _pastelBox(color: const Color(0xFFFFD6E0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('💪 Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: parts.map((p){
        bool sel = w[p] ?? false;
        return FilterChip(label: Text(p), selected: sel, onSelected: (v){ w[p]=v; _saveWorkout(w); });
      }).toList()),
    ]));
  }
  Widget _meditationCard(Map day){
    double target = getTarget('Meditation', 20);
    double done = (day['meditation'] ?? 0).toDouble();
    return _pastelBox(color: const Color(0xFFD6FFE0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('🧘 Meditation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        InkWell(onTap: ()=>_editTarget('Meditation', target), child: Text('Target: ${target.toInt()}m ✏️', style: const TextStyle(color: Colors.grey))),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: (done/target).clamp(0,1), minHeight: 10, borderRadius: BorderRadius.circular(10)),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: Text('${done.toInt()} / ${target.toInt()} min')), _smallBtn('+5', ()=>_updateMed(done+5)), const SizedBox(width:6), _smallBtn('+10', ()=>_updateMed(done+10))]),
    ]));
  }
  Widget _readingCard(Map day){
    double target = getTarget('Reading', 1);
    double done = (day['reading'] ?? 0).toDouble();
    return _pastelBox(color: const Color(0xFFFFE6CC), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('📚 Reading', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        InkWell(onTap: ()=>_editTarget('Reading', target), child: Text('Target: ${target}h ✏️', style: const TextStyle(color: Colors.grey))),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: (done/target).clamp(0,1), minHeight: 10, borderRadius: BorderRadius.circular(10)),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: Text('$done / $target h')), _smallBtn('+0.5', ()=>_updateRead(done+0.5)), const SizedBox(width:6), _smallBtn('+1', ()=>_updateRead(done+1))]),
    ]));
  }

  Widget _smallBtn(String t, VoidCallback f)=> ElevatedButton(onPressed: f, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal:12)), child: Text(t, style: const TextStyle(fontSize:12)));

  void _updateSleep(double v){ var m=getDay(date); m['sleep']=v.clamp(0,24); saveDay(date,m); setState((){}); }
  void _updateWater(double v){ var m=getDay(date); m['water']=v.clamp(0,10000); saveDay(date,m); setState((){}); }
  void _saveFood(Map f){ var m=getDay(date); m['food']=f; saveDay(date,m); setState((){}); }
  void _saveWorkout(Map w){ var m=getDay(date); m['workout']=w; saveDay(date,m); setState((){}); }
  void _updateMed(double v){ var m=getDay(date); m['meditation']=v; saveDay(date,m); setState((){}); }
  void _updateRead(double v){ var m=getDay(date); m['reading']=v; saveDay(date,m); setState((){}); }
  void _updateCustom(String n, double v){ var m=getDay(date); m['custom_$n']=v.clamp(0,1000); saveDay(date,m); setState((){}); }

  void _editTarget(String cat, double cur) async {
    final c = TextEditingController(text: cur.toString());
    final res = await showDialog<String>(context: context, builder: (ctx)=> AlertDialog(title: Text('Target for $cat'), content: TextField(controller: c, keyboardType: TextInputType.number), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: ()=>Navigator.pop(ctx, c.text), child: const Text('Save'))]));
    if(res!=null){ Hive.box('targets').put(cat, double.tryParse(res)??cur); setState((){}); }
  }
  void _addCategory() async {
    final c = TextEditingController();
    final res = await showDialog<String>(context: context, builder: (ctx)=> AlertDialog(title: const Text('New Category'), content: TextField(controller: c, decoration: const InputDecoration(hintText: 'e.g. Yoga, Steps, Skincare')), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: ()=>Navigator.pop(ctx, c.text), child: const Text('Add'))]));
    if(res!=null && res.isNotEmpty){ Hive.box('custom_cats').put(res, true); setState((){}); }
  }
}

class CalendarPage extends StatefulWidget { const CalendarPage({super.key}); @override State<CalendarPage> createState()=>_CalState();}
class _CalState extends State<CalendarPage> {
  DateTime focused = DateTime.now();
  DateTime? selected;
  @override Widget build(BuildContext context){
    return SafeArea(child: Column(children: [
      const SizedBox(height: 10),
      Text('Calendar 🗓️', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      TableCalendar(firstDay: DateTime.utc(2023,1,1), lastDay: DateTime.utc(2030,12,31), focusedDay: focused,
        selectedDayPredicate: (d)=> isSameDay(selected, d),
        onDaySelected: (s,f){ setState((){ selected=s; focused=f; }); },
        calendarStyle: const CalendarStyle(todayDecoration: BoxDecoration(color: Color(0xFFFFB5C2), shape: BoxShape.circle)),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      ),
      if(selected!=null) _dayDetail(DateFormat('yyyy-MM-dd').format(selected!)),
    ]));
  }
  Widget _dayDetail(String key){
    final m = getDay(key);
    if(m.isEmpty) return Padding(padding: const EdgeInsets.all(20), child: Text('No data for $key'));
    return Padding(padding: const EdgeInsets.all(16), child: Text('Details: Sleep ${m['sleep']??0}h, Water ${m['water']??0}ml, Reading ${m['reading']??0}h, Meditation ${m['meditation']??0}m'));
  }
}

class StatsFullPage extends StatelessWidget {
  const StatsFullPage({super.key});
  List<FlSpot> _spots(String field){
    List<FlSpot> s=[];
    for(int i=6;i>=0;i--){
      final d = DateTime.now().subtract(Duration(days: i));
      final k = DateFormat('yyyy-MM-dd').format(d);
      final m = getDay(k);
      double v=0;
      if(field=='water') v=(m['water']??0).toDouble();
      if(field=='sleep') v=(m['sleep']??0).toDouble();
      if(field=='reading') v=(m['reading']??0).toDouble();
      if(field=='meditation') v=(m['meditation']??0).toDouble();
      s.add(FlSpot((6-i).toDouble(), v));
    }
    return s;
  }
  @override Widget build(BuildContext context){
    return SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
      Text('Progress 📊', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const Text('Weekly (last 7 days)'),
      const SizedBox(height: 16),
      _chartCard('💧 Water', _spots('water'), Colors.blue),
      _chartCard('🌙 Sleep', _spots('sleep'), Colors.purple),
      _chartCard('📚 Reading', _spots('reading'), Colors.orange),
      _chartCard('🧘 Meditation', _spots('meditation'), Colors.green),
    ]));
  }
  Widget _chartCard(String title, List<FlSpot> spots, Color col){
    return Container(margin: const EdgeInsets.only(bottom:16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height:12),
      SizedBox(height: 180, child: LineChart(LineChartData(
        gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(rightTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles:false))),
        lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: col, barWidth: 3, dotData: const FlDotData(show:true))],
      ))),
    ]));
  }
}

class SettingsFullPage extends StatelessWidget {
  const SettingsFullPage({super.key});
  @override Widget build(BuildContext context){
    return SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
      Text('Settings ⚙️', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height:16),
      const ListTile(title: Text('Reminders'), subtitle: Text('Water 9am,3pm,9pm | Workout 5pm | Reading 6pm | Sleep 10pm')),
    ])));
  }
}
