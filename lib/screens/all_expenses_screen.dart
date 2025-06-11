import 'package:financial_management_app/models/expense.dart';
import 'package:financial_management_app/models/expense_category.dart';
import 'package:financial_management_app/widgets/expense_list.dart';
import 'package:financial_management_app/services/transaction_service.dart';

import 'package:flutter/material.dart';

class AllExpenseList extends StatefulWidget {
  const AllExpenseList({super.key});

  @override
  State<AllExpenseList> createState() => _AllExpenseListState();
}

class _AllExpenseListState extends State<AllExpenseList> {
  String selectedTab = "Expenses";

  final List<String> tabs = ["All", "Expenses", "Income"];
  late Future<List<Expense>> _latestTransactions;

  List<Map<String, dynamic>> _categorySummaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadCategorySummaries();
  }

  void _loadTransactions() {
    _latestTransactions = TransactionService().fetchLatestTransactions(selectedTab);
  }

  Future<void> _loadCategorySummaries() async {
    final summaries = await TransactionService().fetchCategorySummaries(selectedTab); 
    setState(() {
      _categorySummaries = summaries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Text(
                selectedTab,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildFilterTabs(),
              const SizedBox(height: 16),
              _buildInfoRow(),
              const SizedBox(height: 20),
              _buildSectionHeader('Last Transactions'),
              const SizedBox(height: 8),
              FutureBuilder<List<Expense>>(
                future: _latestTransactions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text("No recent transactions.");
                  }

                  return Column(
                    children: snapshot.data!
                        .map((tx) => _buildTransactionItem(
                              tx.description,
                              'Rp. ${tx.amount}',
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Categories', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildCategoryGrid(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    Color transactionColor;
    Color? backgroundColor;

    if (selectedTab == 'Income') {
      transactionColor = Colors.green;
      backgroundColor = Colors.green[100];
    } else if (selectedTab == 'Expenses') {
      transactionColor = Colors.red;
      backgroundColor = Colors.pink[100];
    } else {
      transactionColor = Colors.black;
      backgroundColor = Colors.grey[400];
    }


    return Row(
      children: tabs.map((tab) {
        bool isSelected = selectedTab == tab;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedTab = tab;
                _loadTransactions();
                _loadCategorySummaries();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? backgroundColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  color: isSelected ? transactionColor : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow() {
    String imagePath;

    if (selectedTab == 'Income'){
      imagePath = 'assets/images/income_pig.png';
    }
    else{
      imagePath = 'assets/images/expenses_pig.png';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(imagePath, height: 128), 
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "BTW, did you know that by clicking on any transaction, you can see more detailed information about it?",
              style: TextStyle(fontSize: 15),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      GestureDetector(
        onTap: () {    
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseList(initialFilter: selectedTab)
            )
          );
        },
        child: const Text(
          'See all',
          style: TextStyle(color: Colors.blue),
        ),
      ),
    ],
  );
}



  Widget _buildTransactionItem(String title, String amountText) {
    String subtitle;
    Color transactionColor;

    if (selectedTab == 'Income') {
      subtitle = 'Income';
      transactionColor = Colors.green;
    } else if (selectedTab == 'Expenses') {
      subtitle = 'Expense';
      transactionColor = Colors.red;
    } else {
      subtitle = 'Transaction';
      transactionColor = Colors.black;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.store, color: Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          amountText,
          style: TextStyle(
            color: transactionColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }


  Widget _buildCategoryGrid() {
    if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
    }

    if (_categorySummaries.isEmpty) {
        return const Text("No categories found.");
    }
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: _categorySummaries.map((summary) {
        final category = summary['category'] as ExpenseCategory;
        final total = summary['total'] as double;

        return _buildCategoryCard(
          category.name,
          'Rp. ${total.toStringAsFixed(0)}',
          category.iconUrl,
        );
      }).toList(),
    );
  }

  Widget _buildCategoryCard(String title, String amount, String iconUrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              iconUrl,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.image_not_supported, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(amount),
            ],
          )
        ],
      ),
    );
  }
}
