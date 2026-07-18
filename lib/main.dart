import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_lock_provider.dart';
import 'core/utils/router.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: ScanSignSendApp()));
}

class ScanSignSendApp extends ConsumerStatefulWidget {
  const ScanSignSendApp({super.key});

  @override
  ConsumerState<ScanSignSendApp> createState() => _ScanSignSendAppState();
}

class _ScanSignSendAppState extends ConsumerState<ScanSignSendApp> {
  late final Future<bool> _onboardingDoneFuture;

  @override
  void initState() {
    super.initState();
    _onboardingDoneFuture = isOnboardingDone();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingDoneFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Splash while checking prefs
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (!snapshot.data!) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            home: OnboardingScreen(
              onDone: () => setState(() {
                _onboardingDoneFuture = Future.value(true);
              }),
            ),
          );
        }
        return _MainApp();
      },
    );
  }
}

class _MainApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return AppLockGate(
      child: MaterialApp.router(
        title: 'Scan Sign Send',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
