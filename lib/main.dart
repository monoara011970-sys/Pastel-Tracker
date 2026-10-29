import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

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
    if (time.isBefore(now)) time = time.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id, t, b, time,
      const NotificationDetails(android: AndroidNotificationDetails('pastel_daily', 'Daily Reminders', importance: Importance.max)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  static Future scheduleAll() async {
    await _schedule(1, 9, 0, 'Good Morning! 💧', 'Time to log water - stay hydrated!');
    await _schedule(2, 15, 0, 'Afternoon Check ☀️', 'Have you had water?');
    await _schedule(3, 21, 0, 'Night Reminder 🌙', 'Log your water & sleep!');
    await _schedule(4, 15, 5, 'Workout Time! 💪', '3:05 PM - Time for your workout!');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('water');
  await Hive.openBox('workout');
  await Hive.openBox('custom');
  await Hive.openBox('settings');
  await NotificationService.init();
  await NotificationService.scheduleAll();
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
        scaffoldBackgroundColor: const Color(0xFFFFF6F7),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int idx = 0;
  final pages = [const TodayPage(), const StatsPage(), const SettingsPage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final waterBox = Hive.box('water');
  final workoutBox = Hive.box('workout');
  final customBox = Hive.box('custom');
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  int water = 0;
  bool workoutDone = false;
  final List<String> defaultCategories = ['Study', 'Exercise', 'Sleep', 'Mood'];

  @override
  void initState() {
    super.initState();
    load();
  }
  void load() {
    setState(() {
      water = waterBox.get(today, defaultValue: 0);
      workoutDone = workoutBox.get(today, defaultValue: false);
    });
  }
  void addWater(int ml) {
    water += ml;
    waterBox.put(today, water);
    setState(() {});
  }
  void toggleWorkout() {
    workoutDone = !workoutDone;
    workoutBox.put(today, workoutDone);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final customKeys = customBox.keys.toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Hello! 🌸', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(DateFormat('EEEE, MMM d').format(DateTime.now()), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('💧 Water', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$water / 2000 ml', style: const TextStyle(color: Colors.grey))
              ]),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (water / 2000).clamp(0, 1), borderRadius: BorderRadius.circular(10), minHeight: 12),
              const SizedBox(height: 16),
              Row(children: [
                _waterBtn('250ml', () => addWater(250)),
                const SizedBox(width: 10),
                _waterBtn('500ml', () => addWater(500)),
                const SizedBox(width: 10),
                _waterBtn('Reset', () { waterBox.put(today, 0); load(); }, isReset: true),
              ])
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFFFE4EC), borderRadius: BorderRadius.circular(24)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💪 Workout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Daily 3:05 PM reminder')
              ]),
              Switch(value: workoutDone, onChanged: (_) => toggleWorkout())
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Custom Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...defaultCategories.map((c) => _catTile(c)),
          ...customKeys.map((k) => _catTile(k.toString(), isCustom: true)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final ctrl = TextEditingController();
              final res = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('New Category'),
                content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'e.g. Reading')),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add'))],
              ));
              if (res != null && res.isNotEmpty) {
                customBox.put(res, false);
                setState(() {});
              }
            },
            icon: const Icon(Icons.add), label: const Text('Add Category')
          )
        ],
      ),
    );
  }
  Widget _waterBtn(String t, VoidCallback onTap, {bool isReset = false}) {
    return Expanded(child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: isReset ? Colors.grey.shade200 : const Color(0xFFFFB5C2)), child: Text(t)));
  }
  Widget _catTile(String name, {bool isCustom = false}) {
    bool val = false;
    if (isCustom) val = customBox.get(name, defaultValue: false);
    else val = Hive.box('settings').get('${today}_$name', defaultValue: false);
    return Card(
      child: ListTile(
        title: Text(name),
        trailing: Checkbox(value: val, onChanged: (v) {
          if (isCustom) customBox.put(name, v);
          else Hive.box('settings').put('${today}_$name', v);
          setState(() {});
        }),
        leading: isCustom ? IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () { customBox.delete(name); setState(() {}); }) : null,
      ),
    );
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final waterBox = Hive.box('water');
    List<FlSpot> spots = [];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      final v = waterBox.get(key, defaultValue: 0) as int;
      spots.add(FlSpot((6 - i).toDouble(), v.toDouble()));
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Stats 📊', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            height: 250, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: true, rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: const Color(0xFFFF8FA3), barWidth: 3, dotData: const FlDotData(show: true))],
            )),
          ),
          const SizedBox(height: 20),
          const Text('Last 7 days water intake', style: TextStyle(color: Colors.grey))
        ]),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Settings ⚙️', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Column(children: [
              ListTile(title: Text('Water Reminders'), subtitle: Text('9 AM, 3 PM, 9 PM'), trailing: Icon(Icons.notifications_active_rounded, color: Colors.pink)),
              ListTile(title: Text('Workout Reminder'), subtitle: Text('3:05 PM daily'), trailing: Icon(Icons.fitness_center_rounded, color: Colors.pink)),
              ListTile(title: Text('App Version'), subtitle: Text('1.0.0 - Pastel Tracker')),
            ]),
          ),
          const SizedBox(height: 20),
          Center(child: ElevatedButton(onPressed: () async { await NotificationService.scheduleAll(); }, child: const Text('Test Notifications')))
        ]),
      ),
    );
  }
}
