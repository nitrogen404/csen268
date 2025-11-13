import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  Future<void> _completeOnboarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  List<Map<String, dynamic>> pages = [
    {
      'image': 'assets/images/on1.png',
      'title': 'Build Habits Together',
      'subtitle':
          'Join friends and accountability partners to create lasting habits through shared challenges',
      'icon': Icons.group_outlined,
    },
    {
      'image': 'assets/images/on2.png',
      'title': 'Stay Consistent',
      'subtitle':
          'Track your progress daily and watch your streak grow as you build momentum',
      'icon': Icons.show_chart_rounded,
    },
    {
      'image': 'assets/images/on3.png',
      'title': 'Keep Your Chain Alive',
      'subtitle':
          'Don\'t break the chain! Every check-in keeps the group motivated and connected',
      'icon': Icons.flash_on_outlined,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: pages.length,
                itemBuilder: (_, i) {
                  return _buildPage(
                    pages[i]['image'],
                    pages[i]['title'],
                    pages[i]['subtitle'],
                    pages[i]['icon'],
                  );
                },
              ),
            ),
            // Page Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _index == i ? 20 : 8,
                  decoration: BoxDecoration(
                    color: _index == i
                        ? Colors.deepPurple.shade300
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_index == pages.length - 1) {
                      _completeOnboarding();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _index == pages.length - 1 ? "Get Started" : "Next",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                "Skip",
                style: TextStyle(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 16)
          ],
        ),
      ),
    );
  }

  Widget _buildPage(
    String image,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Image card
        Container(
          height: 260,
          width: 330,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: DecorationImage(
              image: AssetImage(image),
              fit: BoxFit.cover,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.deepPurple),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 300,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}

