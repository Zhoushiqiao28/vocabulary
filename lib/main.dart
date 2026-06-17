import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences on startup
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences Provider with the actual instance
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocaBA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const InitializationGate(),
    );
  }
}

// Ensure database and seed words are loaded before showing Dashboard
class InitializationGate extends ConsumerWidget {
  const InitializationGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordList = ref.watch(wordListProvider);

    // If word list is empty, it is loading from seed data or preferences
    if (wordList.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpinKitCubeGrid(
                color: AppTheme.primary,
                size: 50.0,
              ),
              const SizedBox(height: 24),
              const Text(
                'Initializing VocaBA...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const DashboardScreen();
  }
}
