import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/create_chain_step1.dart';
import 'pages/profile_page.dart';
import 'pages/sign_in_page.dart'; // Added import

/// Global nav index used by other pages to change tabs
final ValueNotifier<int> navIndex = ValueNotifier<int>(0);

void main() => runApp(const ChainzApp());

class ChainzApp extends StatelessWidget {
  const ChainzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chainz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const SignInPage(), // Starts with sign-in screen
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final _pages = const [HomePage(), CreateChainStep1(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: navIndex,
      builder: (context, idx, _) {
        return Scaffold(
          body: _pages[idx],
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) => navIndex.value = i,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Create',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
