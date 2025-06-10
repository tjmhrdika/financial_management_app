import 'package:flutter/material.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> introData = [
    {
      'title': 'Manage Your Expenses, Income,\nand Even Savings',
      'subtitle': 'You can easily monitor your transaction\nhistory and track your savings',
      'image': 'assets/images/intro1.png',
      'buttonText': 'Next',
    },
    {
      'title': 'Create Convenient Categories for Your Expenses',
      'subtitle': 'Group expenses into different categories\nDon’t forget to choose suitable emojis',
      'image': 'assets/images/intro2.png',
      'buttonText': 'Next',
    },
    {
      'title': 'Discover Clear and Simple Statistics',
      'subtitle': 'No boring and complicated tables just\nclear and understanding graphs',
      'image': 'assets/images/intro3.png',
      'buttonText': 'Log In',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemCount: introData.length,
        itemBuilder: (context, index) {
          final data = introData[index];
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(data['image']!, height: 200),
                const SizedBox(height: 40),
                Text(
                  data['title']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  data['subtitle']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: index == 0
                        ? Colors.purple[100]
                        : index == 1
                        ? Colors.green[100]
                        : Colors.red[200],
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  ),
                  onPressed: () {
                    if (index < introData.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  child: Text(
                    data['buttonText']!,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(introData.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == i ? Colors.black : Colors.grey[300],
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
