import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  double _balance = 0.0;
  Map<String, double> _incomeData = {};
  Map<String, double> _expenseData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser!;
    final formatter = DateFormat('yyyy-MM-dd');

    Map<String, double> incomeByDate = {};
    Map<String, double> expenseByDate = {};
    double totalIncome = 0;
    double totalExpense = 0;

    final incomeSnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('incomes')
        .get();

    for (var doc in incomeSnapshot.docs) {
      final data = doc.data();
      final date = formatter.format((data['date'] as Timestamp).toDate());
      final amount = (data['amount'] ?? 0).toDouble();
      incomeByDate[date] = (incomeByDate[date] ?? 0) + amount;
      totalIncome += amount;
    }

    // Fetch expenses
    final expenseSnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .get();

    for (var doc in expenseSnapshot.docs) {
      final data = doc.data();
      final date = formatter.format((data['date'] as Timestamp).toDate());
      final amount = (data['amount'] ?? 0).toDouble();
      expenseByDate[date] = (expenseByDate[date] ?? 0) + amount;
      totalExpense += amount;
    }

    setState(() {
      _balance = totalIncome - totalExpense;
      _incomeData = incomeByDate;
      _expenseData = expenseByDate;
      _loading = false;
    });
  }

  LineChartData _buildLineChartData() {
    final allDates = {..._incomeData.keys, ..._expenseData.keys}.toList()
      ..sort();
    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];

    for (int i = 0; i < allDates.length; i++) {
      final date = allDates[i];
      incomeSpots.add(FlSpot(i.toDouble(), _incomeData[date] ?? 0));
      expenseSpots.add(FlSpot(i.toDouble(), _expenseData[date] ?? 0));
    }

    return LineChartData(
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < allDates.length) {
                return Text(allDates[index].substring(5)); // show MM-dd
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: incomeSpots,
          isCurved: false,
          color: Colors.green,
          barWidth: 2,
        ),
        LineChartBarData(
          spots: expenseSpots,
          isCurved: false,
          color: Colors.red,
          barWidth: 2,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child:
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/images/home_pig.png', height: 128),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Hi there! I will help you get your finances in order.",
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                )
              ],
            ),
            SizedBox(height: 24),
            Text("Available Balance", style: TextStyle(fontSize: 18)),
            Text(
              "Rp${_balance.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            Text("Income vs Expense", style: TextStyle(fontSize: 18)),
            SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.6,
              child: LineChart(_buildLineChartData()),
            ),
          ],
        ),
      ),
    );
  }
}
