import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/school_brand.dart';

/// Splash screen shown on app startup.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeController.repeat(reverse: true, period: const Duration(milliseconds: 1500));
    _scaleController.repeat(reverse: true, period: const Duration(milliseconds: 2000));

    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;

    if (user == null) {
      context.go('/login');
    } else {
      // Fetch role from Firestore and navigate to dashboard
      final role = await ref.read(userRoleProvider.future);
      final route = await getUserRoleRoute(role);
      if (!mounted) return;
      context.go(route);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleController,
              child: FadeTransition(
                opacity: _fadeController,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(70),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: SchoolBrand(
                      compact: false,
                      light: true,
                      showName: false,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Parent, Student Attendance & Bus Tracking',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Colors.white70,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Determine the user role and return the appropriate dashboard route.
Future<String> getUserRoleRoute(String role) async {
  switch (role) {
    case AppConstants.roleAdmin:
      return '/admin/dashboard';
    case AppConstants.roleParent:
      return '/parent/dashboard';
    case AppConstants.roleTeacher:
      return '/teacher/dashboard';
    case AppConstants.roleDriver:
      return '/driver/dashboard';
    default:
      return '/login';
  }
}
