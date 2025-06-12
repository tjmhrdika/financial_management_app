import 'package:flutter/material.dart';
import 'package:financial_management_app/widgets/navigation_bar.dart';
import 'package:financial_management_app/screens/savings_goal_screen.dart';
import 'package:financial_management_app/screens/home_dashboard_screen.dart';
import 'package:financial_management_app/screens/all_expenses_screen.dart';
import 'package:financial_management_app/widgets/add_expense_form.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _checkedArgs = false; 

  final List<Widget> _screens = [
    const HomeDashboardScreen(),
    const AllExpenseList(),
    const AddExpenseForm(),
    const SavingsGoalsScreen(),
  ];


void _showLogoutDialog() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.logout, color: Colors.red[600]),
          SizedBox(width: 8),
          Text('Logout'),
        ],
      ),
      content: Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _handleLogout();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
          child: Text('Logout'),
        ),
      ],
    ),
  );
}


void _handleLogout() async {
  try {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged out successfully')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}


  void _onNavItemTapped(int index) {
    if (index == 4) {
      _showLogoutDialog();
    }
    else{
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedArgs) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final tab = args?['initialTab'];
      
      if (tab == 'expenses') _currentIndex = 1;
      if (tab == 'budgeting') _currentIndex = 3;
      
      _checkedArgs = true;
    }
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }
}