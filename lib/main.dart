import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'transaction.dart'; // 👈 ab model alag file me h

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter()); // auto-gen adapter
  await Hive.openBox<Transaction>('transactions');

  runApp(UPITrackerApp());
}

class UPITrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline UPI Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: SplashScreen(),
    );
  }
}

// ---------------- Splash Screen ----------------
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
        MaterialPageRoute(builder: (_) => UPISelectionScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 150,
              height: 150,
            ),
            SizedBox(height: 20),
            Text(
              'Offline UPI Tracker',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- UPI Selection ----------------
class UPISelectionScreen extends StatefulWidget {
  @override
  _UPISelectionScreenState createState() => _UPISelectionScreenState();
}

class _UPISelectionScreenState extends State<UPISelectionScreen> {
  List<String> allUPIApps = [
    'Google Pay',
    'PhonePe',
    'Paytm',
    'Amazon Pay',
    'Kotak Mahindra',
    'HDFC',
    'ICICI',
    'SBI',
    'BOB',
    'BHIM',
  ];
  List<String> selectedApps = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select UPI Apps')),
      body: ListView(
        children: allUPIApps.map((app) {
          bool selected = selectedApps.contains(app);
          return ListTile(
            title: Text(app),
            trailing:
                selected ? Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              setState(() {
                selected
                    ? selectedApps.remove(app)
                    : selectedApps.add(app);
              });
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.arrow_forward),
        onPressed: () {
          if (selectedApps.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DashboardScreen(selectedApps: selectedApps),
              ),
            );
          }
        },
      ),
    );
  }
}

// ---------------- Dashboard ----------------
class DashboardScreen extends StatefulWidget {
  final List<String> selectedApps;
  DashboardScreen({required this.selectedApps});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Box<Transaction> box = Hive.box<Transaction>('transactions');
  Transaction? latestTransaction;

  @override
  void initState() {
    super.initState();
    fetchLatestTransaction();
    // TODO: Implement notification listener to call addTransactionFromNotification()
  }

  void fetchLatestTransaction() {
    final allTxns = box.values.toList();
    if (allTxns.isNotEmpty) {
      allTxns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        latestTransaction = allTxns.first;
      });
    }
  }

  void addTransactionFromNotification(Transaction txn) {
    box.add(txn);
    fetchLatestTransaction();
  }

  void addPurpose(Transaction txn) async {
    TextEditingController controller = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Add Purpose'),
              content: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: 'Enter purpose/message'),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      txn.message = controller.text;
                      txn.save();
                      Navigator.pop(context);
                      fetchLatestTransaction();
                    },
                    child: Text('Save'))
              ],
            ));
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
                        items: widget.selectedApps
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setStateSB(() {
                            selectedApp = val;
                          });
                        },
                      ),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(hintText: 'Amount'),
                      ),
                      TextField(
                        controller: fromCtrl,
                        decoration: InputDecoration(
                            hintText: 'From Account Last 4 digits'),
                      ),
                      TextField(
                        controller: toCtrl,
                        decoration: InputDecoration(
                            hintText: 'To Account Last 4 digits'),
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
                          final txn = Transaction(
                              upiApp: selectedApp!,
                              amount: double.parse(amountCtrl.text),
                              fromAccount: fromCtrl.text,
                              toAccount: toCtrl.text,
                              message:
                                  msgCtrl.text.isEmpty ? null : msgCtrl.text,
                              timestamp: DateTime.now());
                          box.add(txn);
                          Navigator.pop(context);
                          fetchLatestTransaction();
                        }
                      },
                      child: Text('Save'))
                ],
              );
            }));
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
              onPressed: addManualTransaction, icon: Icon(Icons.add))
        ],
      ),
      body: Column(
        children: [
          // Latest Transaction Banner
          if (latestTransaction != null)
            Card(
              color: Colors.green[100],
              margin: EdgeInsets.all(8),
              child: ListTile(
                title: Text(
                    'You paid ₹${latestTransaction!.amount} via ${latestTransaction!.upiApp}'),
                subtitle: Text(
                    'From: ****${latestTransaction!.fromAccount} → To: ****${latestTransaction!.toAccount}\n'
                    'Message: ${latestTransaction!.message ?? "[Not added]"}\n'
                    'Date: ${latestTransaction!.timestamp}'),
                trailing: latestTransaction!.message == null
                    ? IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => addPurpose(latestTransaction!),
                      )
                    : null,
              ),
            ),
          SizedBox(height: 8),
          Text(
            'Past Transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
              child: ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('₹${txn.amount} via ${txn.upiApp}'),
                  subtitle: Text(
                      'From: ****${txn.fromAccount} → To: ****${txn.toAccount}\n'
                      'Message: ${txn.message ?? "[Not added]"}\n'
                      'Date: ${txn.timestamp}'),
                  trailing: txn.message == null
                      ? TextButton(
                          onPressed: () => addPurpose(txn),
                          child: Text('Add Purpose'),
                        )
                      : null,
                ),
              );
            },
          )),
        ],
      ),
    );
  }
}
