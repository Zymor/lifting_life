import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/auth_onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rankings_screen.dart';
import 'screens/workouts_screen.dart';
import 'services/data_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String? _userId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _userId = DataService.instance.currentUser?.id;
    _ready = DataService.instance.isAuthenticated && DataService.instance.hasCompletedOnboarding;
    DataService.instance.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final data = DataService.instance;
    final ready = data.isAuthenticated && data.hasCompletedOnboarding;
    final userId = data.currentUser?.id;
    if (_ready == ready && _userId == userId) return;
    setState(() {
      _ready = ready;
      _userId = userId;
      _selectedIndex = 0;
    });
  }

  @override
  void dispose() {
    DataService.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
        final data = DataService.instance;
        if (!data.isAuthenticated || !data.hasCompletedOnboarding) {
          return const AuthOnboardingScreen();
        }

        final screens = [
          DashboardScreen(
            onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
          ),
          const ExercisesScreen(),
          const WorkoutsScreen(),
          const RankingsScreen(),
          const ProfileScreen(),
        ];

        final isDesktop = MediaQuery.of(context).size.width > 840;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: AppTheme.surfaceColor,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(
                    color: AppTheme.primaryColor,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.view_in_ar_outlined),
                      selectedIcon: Icon(Icons.view_in_ar),
                      label: Text('Exercises'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.fitness_center_outlined),
                      selectedIcon: Icon(Icons.fitness_center),
                      label: Text('Workout'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.leaderboard_outlined),
                      selectedIcon: Icon(Icons.leaderboard),
                      label: Text('Rankings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: screens[_selectedIndex]),
              ],
            ),
          );
        }

        return Scaffold(
          body: screens[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            backgroundColor: AppTheme.surfaceColor,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.18),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(
                  Icons.home,
                  color: AppTheme.primaryColor,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.view_in_ar_outlined),
                selectedIcon: Icon(
                  Icons.view_in_ar,
                  color: AppTheme.primaryColor,
                ),
                label: 'Exercises',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(
                  Icons.fitness_center,
                  color: AppTheme.primaryColor,
                ),
                label: 'Workout',
              ),
              NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(
                  Icons.leaderboard,
                  color: AppTheme.primaryColor,
                ),
                label: 'Rankings',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(
                  Icons.person,
                  color: AppTheme.primaryColor,
                ),
                label: 'Profile',
              ),
            ],
          ),
        );
  }
}
