import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  String upiApp;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String fromAccount;

  @HiveField(3)
  String toAccount;

  @HiveField(4)
  String? message;

  @HiveField(5)
  DateTime timestamp;

  Transaction({
    required this.upiApp,
    required this.amount,
    required this.fromAccount,
    required this.toAccount,
    this.message,
    required this.timestamp,
  });
}
