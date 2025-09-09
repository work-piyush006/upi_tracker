import 'package:flutter/foundation.dart'; // for kReleaseMode
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'transaction.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  await Hive.openBox<Transaction>('transactions');
  runApp(UPITrackerApp());
}

// ---------------- UPI TRACKER APP ----------------
class UPITrackerApp extends StatefulWidget {
  @override
  _UPITrackerAppState createState() => _UPITrackerAppState();
}

class _UPITrackerAppState extends State<UPITrackerApp> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticated = false;

  Future<void> _authenticate() async {
    try {
      _isAuthenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access UPI Tracker',
        options: const AuthenticationOptions(
          biometricOnly: true,
        ),
      );
      setState(() {});
    } catch (e) {
      _isAuthenticated = false;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Please authenticate to open app',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offline UPI Tracker',
      theme: ThemeData(primarySwatch: Colors.green),
      home: SplashScreen(),
    );
  }
}

// ---------------- SPLASH SCREEN ----------------
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkPermission();
  }

  Future<void> checkPermission() async {
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset('assets/logo.png', width: 150, height: 150),
          SizedBox(height: 20),
          Text(
            'Offline UPI Tracker',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ]),
      ),
    );
  }
}

// ---------------- DASHBOARD SCREEN ----------------
class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Box<Transaction> box = Hive.box<Transaction>('transactions');
  Transaction? latestTransaction;
  bool isDark = false;

  FlutterNotificationListener listener = FlutterNotificationListener();

  Map<String, String> upiLogos = {
    'Google Pay': 'assets/gpay.png',
    'PhonePe': 'assets/phonepe.png',
    'Paytm': 'assets/paytm.png',
    'Amazon Pay': 'assets/amazonpay.png',
    'BHIM': 'assets/bhim.png',
    'SBI': 'assets/sbi.png',
    'HDFC': 'assets/hdfc.png',
    'ICICI': 'assets/icici.png',
    'BOB': 'assets/bob.png',
    'Kotak Mahindra': 'assets/kotak.png',
  };

  @override
  void initState() {
    super.initState();
    fetchLatestTransaction();

    if (!kReleaseMode) {
      listener.initialize();
      listener.notifications?.listen((notif) {
        parseNotification(notif);
      });
    }
  }

  void fetchLatestTransaction() {
    final allTxns = box.values.toList();
    if (allTxns.isNotEmpty) {
      allTxns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() => latestTransaction = allTxns.first);
    }
  }

  void parseNotification(NotificationEvent notif) {
    String body = notif.text?.toLowerCase() ?? '';
    if (body.contains('paid') || body.contains('received')) {
      String app = '';
      upiLogos.keys.forEach((k) {
        if (notif.packageName != null &&
            notif.packageName!.toLowerCase().contains(k.toLowerCase()))
          app = k;
      });

      double amount = 0.0;
      try {
        RegExp exp = RegExp(r'₹\s*([0-9]+(?:\.[0-9]{1,2})?)');
        Match? m = exp.firstMatch(body);
        if (m != null) amount = double.parse(m.group(1)!);
      } catch (e) {
        amount = 0.0;
      }

      if (amount > 0 && app.isNotEmpty) {
        Transaction txn = Transaction(
          upiApp: app,
          amount: amount,
          fromAccount: '****',
          toAccount: '****',
          timestamp: DateTime.now(),
        );
        box.add(txn);
        fetchLatestTransaction();
      }
    }
  }

  void addManualTransaction() {
    TextEditingController amountCtrl = TextEditingController();
    TextEditingController fromCtrl = TextEditingController();
    TextEditingController toCtrl = TextEditingController();
    TextEditingController msgCtrl = TextEditingController();
    String? selectedApp;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setStateSB) {
        return AlertDialog(
          title: Text('Add Transaction'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButton<String>(
                  hint: Text('Select UPI App'),
                  value: selectedApp,
                  isExpanded: true,
                  items: upiLogos.keys
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Row(children: [
                              Image.asset(upiLogos[e]!, width: 24, height: 24),
                              SizedBox(width: 8),
                              Text(e),
                            ]),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setStateSB(() => selectedApp = val);
                  },
                ),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'Amount'),
                ),
                TextField(
                  controller: fromCtrl,
                  decoration: InputDecoration(hintText: 'From Account Last 4 digits'),
                ),
                TextField(
                  controller: toCtrl,
                  decoration: InputDecoration(hintText: 'To Account Last 4 digits'),
                ),
                TextField(
                  controller: msgCtrl,
                  decoration: InputDecoration(hintText: 'Purpose'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (selectedApp != null &&
                    amountCtrl.text.isNotEmpty &&
                    fromCtrl.text.isNotEmpty &&
                    toCtrl.text.isNotEmpty) {
                  Transaction txn = Transaction(
                    upiApp: selectedApp!,
                    amount: double.parse(amountCtrl.text),
                    fromAccount: fromCtrl.text,
                    toAccount: toCtrl.text,
                    message: msgCtrl.text.isEmpty ? null : msgCtrl.text,
                    timestamp: DateTime.now(),
                  );
                  box.add(txn);
                  fetchLatestTransaction();
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            )
          ],
        );
      }),
    );
  }

  Future<void> exportCSV() async {
    List<List<String>> rows = [
      ['UPI App', 'Amount', 'From', 'To', 'Message', 'Date']
    ];
    for (var txn in box.values) {
      rows.add([
        txn.upiApp,
        txn.amount.toString(),
        txn.fromAccount,
        txn.toAccount,
        txn.message ?? '',
        txn.timestamp.toString(),
      ]);
    }
    String csv = const ListToCsvConverter().convert(rows);
    Directory dir = await getApplicationDocumentsDirectory();
    File file = File('${dir.path}/transactions.csv');
    await file.writeAsString(csv);
  }

  @override
  Widget build(BuildContext context) {
    List<Transaction> transactions = box.values.toList();
    transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: () => setState(() => isDark = !isDark),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/logo.png', width: 60, height: 60),
                  SizedBox(height: 10),
                  Text('Offline UPI Tracker',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('All Transactions'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AllTransactionsScreen())),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                          exportCSV: exportCSV,
                          clearAll: () {
                            box.clear();
                            fetchLatestTransaction();
                          }))),
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('About'),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => AboutScreen())),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (latestTransaction != null)
            Card(
              color: Colors.green[100],
              margin: EdgeInsets.all(8),
              child: ListTile(
                leading: Image.asset(
                  upiLogos[latestTransaction!.upiApp] ?? 'assets/logo.png',
                  width: 40,
                  height: 40,
                ),
                title: Text(
                    '₹${latestTransaction!.amount} via ${latestTransaction!.upiApp}'),
                subtitle: Text(
                  'From: ${latestTransaction!.fromAccount} → To: ${latestTransaction!.toAccount}\n'
                  'Message: ${latestTransaction!.message ?? "[Not added]"}\n'
                  'Date: ${latestTransaction!.timestamp}',
                ),
              ),
            ),
          SizedBox(height: 8),
          Text('Past Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final txn = transactions[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Image.asset(
                        upiLogos[txn.upiApp] ?? 'assets/logo.png',
                        width: 32,
                        height: 32),
                    title: Text('₹${txn.amount} via ${txn.upiApp}'),
                    subtitle: Text(
                      'From: ${txn.fromAccount} → To: ${txn.toAccount}\n'
                      'Message: ${txn.message ?? "[Not added]"}\n'
                      'Date: ${txn.timestamp}',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(onPressed: addManualTransaction, child: Icon(Icons.add)),
    );
  }
}

// ---------------- ALL TRANSACTIONS SCREEN ----------------
class AllTransactionsScreen extends StatelessWidget {
  final Box<Transaction> box = Hive.box<Transaction>('transactions');
  @override
  Widget build(BuildContext context) {
    List<Transaction> transactions = box.values.toList();
    transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Scaffold(
      appBar: AppBar(title: Text('All Transactions')),
      body: ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final txn = transactions[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text('₹${txn.amount} via ${txn.upiApp}'),
              subtitle: Text(
                  'From: ${txn.fromAccount} → To: ${txn.toAccount}\n'
                  'Message: ${txn.message ?? "[Not added]"}\n'
                  'Date: ${txn.timestamp}'),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- SETTINGS SCREEN ----------------
class SettingsScreen extends StatelessWidget {
  final Function exportCSV;
  final Function clearAll;

  SettingsScreen({required this.exportCSV, required this.clearAll});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.download),
            title: Text('Export Transactions (CSV)'),
            onTap: () async {
              await exportCSV();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Transactions exported successfully!')),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Clear All Transactions'),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Confirm'),
                  content: Text('Are you sure you want to delete all transactions?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel')),
                    TextButton(
                        onPressed: () {
                          clearAll();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('All transactions cleared!')),
                          );
                        },
                        child: Text('Yes')),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('About App'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- ABOUT SCREEN ----------------
class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline UPI Tracker',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Version: 1.0.0\n\n'
              'This app allows you to track your UPI transactions offline, '
              'automatically from notifications or manually added. You can also export your transaction history as a CSV file.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              'Developer:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Offline UPI Tracker Made by Useful App Developers'),
          ],
        ),
      ),
    );
  }
}