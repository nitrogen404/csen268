import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/create_chain_step1.dart';
import 'pages/profile_page.dart';
import 'pages/sign_in_page.dart';
import 'pages/sign_up_page.dart';
import 'pages/onboarding_page.dart';
import 'services/toast_notification_service.dart';
import 'services/chain_service.dart';
import 'repository/settings_repository.dart';
import 'cubits/settings_cubit.dart';
import 'models/app_settings.dart';

final ValueNotifier<int> navIndex = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool seen = prefs.getBool('seenOnboarding') ?? false;

  runApp(ChainzApp(showOnboarding: !seen));
}

class ChainzApp extends StatelessWidget {
  final bool showOnboarding;

  const ChainzApp({required this.showOnboarding, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (user == null) {
          return MaterialApp(
            title: 'Chainz',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: ThemeMode.system,
            home: showOnboarding ? const OnboardingPage() : const SignInPage(),
            routes: {
              '/onboarding': (_) => const OnboardingPage(),
              '/login': (_) => const SignInPage(),
              '/signup': (_) => const SignUpPage(),
            },
          );
        }

        final repo = SettingsRepository();

        return BlocProvider<SettingsCubit>(
          create: (_) => SettingsCubit(repo, user.uid),
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              final AppSettings settings =
                  state.settings ?? const AppSettings();

              ThemeMode themeMode;
              switch (settings.darkMode) {
                case 'light':
                  themeMode = ThemeMode.light;
                  break;
                case 'dark':
                  themeMode = ThemeMode.dark;
                  break;
                default:
                  themeMode = ThemeMode.system;
              }

              return MaterialApp(
                title: 'Chainz',
                debugShowCheckedModeBanner: false,
                theme: buildTheme(Brightness.light),
                darkTheme: buildTheme(Brightness.dark),
                themeMode: themeMode,
                locale: Locale(settings.language),
                home: const RootShell(),
                routes: {
                  '/onboarding': (_) => const OnboardingPage(),
                  '/login': (_) => const SignInPage(),
                  '/signup': (_) => const SignUpPage(),
                  '/home': (_) => const RootShell(),
                },
              );
            },
          ),
        );
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

  int _currentIndex = 0;
  bool _reverse = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final chainIds = await ChainService().getJoinedChainIds(uid);
        _toastService.startListening(chainIds);
      }
    });

    navIndex.addListener(_onNavIndexChanged);
    _currentIndex = navIndex.value;
  }

  @override
  void dispose() {
    navIndex.removeListener(_onNavIndexChanged);
    _toastService.dispose();
    super.dispose();
  }

  void _onNavIndexChanged() {
    final newIndex = navIndex.value;
    if (newIndex != _currentIndex) {
      setState(() {
        _reverse = newIndex < _currentIndex;
        _currentIndex = newIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 1000),
        reverse: _reverse,
        transitionBuilder: (
          Widget child,
          Animation<double> primary,
          Animation<double> secondary,
        ) {
          return SharedAxisTransition(
            animation: primary,
            secondaryAnimation: secondary,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          );
        },
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
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
  }
}