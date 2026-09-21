import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_lock_provider.dart';
import 'core/utils/l10n_ext.dart';
import 'core/utils/path_resolver.dart';
import 'core/utils/router.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'shared/theme/app_theme.dart';

void main() {
  // Replace the default red error screen with a calm, branded fallback so a
  // single widget build failure never shows users a scary crash overlay.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    return const _FriendlyErrorWidget();
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Resolve the current app Documents container up front. Stored file paths
      // are rebased onto it so they survive iOS container-UUID changes across
      // reinstalls / restores. Must happen before any screen reads a path.
      await PathResolver.init();
      // Framework errors → log (and forward to zone in debug for visibility).
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };
      runApp(const ProviderScope(child: ScanSignSendApp()));
    },
    (error, stack) {
      // Uncaught async errors land here instead of crashing the isolate.
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

/// Shown in place of a widget that failed to build. Keeps the app usable.
class _FriendlyErrorWidget extends StatelessWidget {
  const _FriendlyErrorWidget();

  @override
  Widget build(BuildContext context) {
    // This renders because some other widget's build threw, so the surrounding
    // Localizations scope may not be reachable. Fall back to English rather
    // than replacing one failure with another.
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sentiment_dissatisfied_outlined,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(l10n?.errorGenericTitle ?? 'Something went wrong here.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                  l10n?.errorGenericBody ??
                      'Try going back and reopening this document.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanSignSendApp extends ConsumerStatefulWidget {
  const ScanSignSendApp({super.key});

  @override
  ConsumerState<ScanSignSendApp> createState() => _ScanSignSendAppState();
}

class _ScanSignSendAppState extends ConsumerState<ScanSignSendApp> {
  late Future<bool> _onboardingDoneFuture;

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
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const Scaffold(
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
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
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
        localizationsDelegates: kLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
      ),
    );
  }
}
