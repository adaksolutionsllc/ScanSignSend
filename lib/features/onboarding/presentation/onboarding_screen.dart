import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/l10n_ext.dart';

const _kOnboardingDone = 'onboarding_done';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  /// Built per-build rather than as a `static const` list: the copy is
  /// localized, so it can only be resolved once a BuildContext exists.
  List<_OnboardingPage> _buildPages(BuildContext context) => [
        _OnboardingPage(
          icon: Icons.document_scanner,
          color: const Color(0xFF1A73E8),
          title: context.l10n.onboardScanTitle,
          subtitle: context.l10n.onboardScanBody,
        ),
        _OnboardingPage(
          icon: Icons.draw,
          color: const Color(0xFF6A1B9A),
          title: context.l10n.onboardSignTitle,
          subtitle: context.l10n.onboardSignBody,
        ),
        _OnboardingPage(
          icon: Icons.send,
          color: const Color(0xFF2E7D32),
          title: context.l10n.onboardSendTitle,
          subtitle: context.l10n.onboardSendBody,
        ),
      ];


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => pages[i],
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? pages[_page].color
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: Text(context.l10n.actionBack),
                    )
                  else
                    TextButton(
                      onPressed: _finish,
                      child: Text(context.l10n.actionSkip),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _page == pages.length - 1
                        ? _finish
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: pages[_page].color,
                      minimumSize: const Size(120, 48),
                    ),
                    child: Text(
                        _page == pages.length - 1 ? context.l10n.onboardGetStarted : context.l10n.actionNext),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
    widget.onDone();
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Returns true if the user has already seen onboarding.
Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) ?? false;
}
