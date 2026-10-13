import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/free_usage_service.dart';
import '../../../core/utils/l10n_ext.dart';

const _kOnboardingDone = 'onboarding_done';

/// Tour pages the user has seen, by id. Kept so an update can show just the
/// pages added since ("What's new") instead of nothing or everything.
const kTourPagesSeen = 'tour_pages_seen';

/// Every tour page, in order. Add an id here when adding a page.
const kTourPageIds = ['scan', 'prefill', 'sign', 'send', 'free'];

/// The pages the first tour (up to 1.1.0) had: users who finished it before
/// pages were tracked have seen these.
const _firstTourPages = {'scan', 'sign', 'send', 'free'};

/// What to show at launch: null for the full tour (first run), otherwise
/// the tour pages added since this user last saw the tour (may be empty).
Future<Set<String>?> unseenTourPages() async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(_kOnboardingDone) ?? false)) return null;
  final seen = prefs.getStringList(kTourPagesSeen)?.toSet() ?? _firstTourPages;
  return kTourPageIds.where((id) => !seen.contains(id)).toSet();
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.only});
  final VoidCallback onDone;

  /// Show just these pages, as "What's new" after an update. Null shows the
  /// whole tour (first run, or Settings → App tour).
  final Set<String>? only;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  /// Built per-build rather than as a `static const` list: the copy is
  /// localized, so it can only be resolved once a BuildContext exists.
  List<_OnboardingPage> _buildPages(BuildContext context) => [
        for (final page in _allPages(context))
          if (widget.only == null || widget.only!.contains(page.id)) page,
      ];

  List<_OnboardingPage> _allPages(BuildContext context) => [
        _OnboardingPage(
          id: 'scan',
          icon: Icons.document_scanner,
          color: const Color(0xFF1A73E8),
          title: context.l10n.onboardScanTitle,
          subtitle: context.l10n.onboardScanBody,
        ),
        // PreFill: fields found and labelled, then filled from My Details.
        _OnboardingPage(
          id: 'prefill',
          icon: Icons.auto_awesome,
          color: const Color(0xFF00897B),
          title: context.l10n.onboardPrefillTitle,
          subtitle: context.l10n.onboardPrefillBody,
        ),
        _OnboardingPage(
          id: 'sign',
          icon: Icons.draw,
          color: const Color(0xFF6A1B9A),
          title: context.l10n.onboardSignTitle,
          subtitle: context.l10n.onboardSignBody,
        ),
        _OnboardingPage(
          id: 'send',
          icon: Icons.send,
          color: const Color(0xFF2E7D32),
          title: context.l10n.onboardSendTitle,
          subtitle: context.l10n.onboardSendBody,
        ),
        _OnboardingPage(
          id: 'free',
          icon: Icons.workspace_premium,
          color: const Color(0xFFE37400),
          title: context.l10n.onboardFreeTitle,
          subtitle: context.l10n.onboardFreeBody(
            FreeUsageService.freeDocuments,
            FreeUsageService.freePageLimit,
          ),
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
            // After an update: only the new pages, under a "What's new" tag.
            if (widget.only != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Chip(
                  avatar: Icon(
                    Icons.new_releases_outlined,
                    size: 18,
                    color: pages[_page].color,
                  ),
                  label: Text(context.l10n.tourWhatsNew),
                ),
              ),
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
                  else if (widget.only == null)
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
                      _page < pages.length - 1
                          ? context.l10n.actionNext
                          : widget.only != null
                          ? context.l10n.tourGotIt
                          : context.l10n.onboardGetStarted,
                    ),
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
    await prefs.setStringList(kTourPagesSeen, kTourPageIds);
    widget.onDone();
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final String id;
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
