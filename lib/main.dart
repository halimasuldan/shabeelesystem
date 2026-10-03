import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase/options.dart';
import 'firebase/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (guarded so a missing/invalid config
  // doesn't produce a blank screen before runApp).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool(AppConstants.prefIsFirstLaunch) ?? true;

  runApp(
    ProviderScope(
      child: ShabelleApp(isFirstLaunch: isFirstLaunch),
    ),
  );
}

class ShabelleApp extends ConsumerWidget {
  final bool isFirstLaunch;

  const ShabelleApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
