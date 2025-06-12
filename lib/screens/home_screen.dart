import 'package:flutter/material.dart';
import 'package:financial_management_app/widgets/navigation_bar.dart';
import 'package:financial_management_app/screens/user_profile_screen.dart';
import 'package:financial_management_app/screens/savings_goal_screen.dart';
import 'package:financial_management_app/screens/home_dashboard_screen.dart';
import 'package:financial_management_app/screens/all_expenses_screen.dart';
import 'package:financial_management_app/widgets/add_expense_form.dart';


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
    const ProfileScreen(),
  ];


  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
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