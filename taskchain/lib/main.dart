import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/create_chain_step1.dart';
import 'pages/profile_page.dart';
import 'pages/sign_in_page.dart';
import 'pages/sign_up_page.dart';
import 'pages/onboarding_page.dart';
import 'services/toast_notification_service.dart';

/// Global nav index used by other pages to change tabs
final ValueNotifier<int> navIndex = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBi8GrZ-W-xhwVM24coK_t77vGlwmEg2jc",
      authDomain: "taskchain-439617.firebaseapp.com",
      projectId: "taskchain-439617",
      storageBucket: "taskchain-439617.firebasestorage.app",
      messagingSenderId: "346823563530",
      appId: "1:346823563530:web:f66013f5d7b730810a02f3",
      measurementId: "G-PD2P5F6JRR",
    ),
  );
  
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool seen = prefs.getBool('seenOnboarding') ?? false;

  runApp(ChainzApp(showOnboarding: !seen));
}

class ChainzApp extends StatelessWidget {
  final bool showOnboarding;

  const ChainzApp({required this.showOnboarding, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chainz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      initialRoute: showOnboarding ? '/onboarding' : '/login',
      routes: {
        '/onboarding': (_) => const OnboardingPage(),
        '/login': (_) => const SignInPage(),
        '/signup': (_) => const SignUpPage(),
        '/home': (_) => const RootShell(),
      },
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
  final _toastService = ToastNotificationService();

  @override
  void initState() {
    super.initState();
    // Initialize toast notifications after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toastService.initialize(context);
      // Start listening to all chains
      _toastService.startListening(['chain_1', 'chain_2', 'chain_3']);
    });
  }

  @override
  void dispose() {
    _toastService.stopListening();
    super.dispose();
  }

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
