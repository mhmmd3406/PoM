import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Route path of the subscription / upsell screen.
///
/// Hardcoded (instead of importing `AppRoutes`) to keep `core/widgets` free of
/// a dependency cycle with `core/router/app_router.dart`, which imports this
/// file. Keep in sync with `AppRoutes.subscription`.
const String kSubscriptionRoute = '/subscription';

/// Pushes the subscription screen so the user can return to where they were.
void goToSubscription(BuildContext context) =>
    context.push(kSubscriptionRoute);

// ─────────────────────────────────────────────────────────────────────────────
// ProGate — inline teaser + upsell overlay
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a premium surface. When [locked] is true the [child] is rendered as a
/// blurred, non-interactive teaser with a centered "Pro'ya Geç" upsell panel on
/// top. When unlocked it returns [child] untouched (zero overhead).
///
/// Use for in-page premium sections (e.g. the advanced Insights views). For a
/// whole premium screen use [ProGateScreen].
class ProGate extends StatelessWidget {
  const ProGate({
    super.key,
    required this.locked,
    required this.child,
    this.title = 'Pro\'ya özel',
    this.message =
        'Bu içgörü Pro üyelere açık. Yükselterek tüm gelişmiş analizlere eriş.',
    this.blurSigma = 7,
    this.minHeight = 260,
    this.onUpgrade,
  });

  /// Whether the gate is active. Typically `!user.isPro`.
  final bool locked;

  /// The premium content. Shown blurred as a teaser when [locked].
  final Widget child;

  final String title;
  final String message;

  /// Gaussian blur strength applied to the teaser.
  final double blurSigma;

  /// Minimum height for the teaser area so short content still reads as a card.
  final double minHeight;

  /// Override the default action (push the subscription screen).
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scrim = (isDark ? AppColors.darkBg : AppColors.lightBg)
        .withValues(alpha: 0.45);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Blurred, inert teaser of the real content. The (non-positioned)
          // teaser drives the Stack's size; the scrim + card fill over it.
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: ImageFiltered(
              imageFilter:
                  ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: IgnorePointer(child: child),
            ),
          ),
          // Scrim + centered upsell card.
          Positioned.fill(
            child: Container(
              color: scrim,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: _UpsellCard(
                title: title,
                message: message,
                onUpgrade: onUpgrade ?? () => goToSubscription(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact upsell card used as the centered overlay inside [ProGate].
class _UpsellCard extends StatelessWidget {
  const _UpsellCard({
    required this.title,
    required this.message,
    required this.onUpgrade,
  });

  final String title;
  final String message;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LockBadge(),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ink2, height: 1.45),
            ),
            const SizedBox(height: 16),
            _UpgradeButton(onUpgrade: onUpgrade),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProGateScreen — full-screen upsell (route-level gating)
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen "Pro'ya özel" placeholder shown in place of a premium screen for
/// free users. Used to gate whole routes (e.g. benchmarking, reports) without
/// touching the gated screen's own widget tree.
class ProGateScreen extends StatelessWidget {
  const ProGateScreen({
    super.key,
    required this.appBarTitle,
    required this.heading,
    required this.message,
    this.bullets = const [],
    this.onBack,
  });

  /// Title shown in the top bar (matches the gated screen's title).
  final String appBarTitle;

  /// Large headline inside the body.
  final String heading;
  final String message;

  /// Optional feature bullet list teasing what Pro unlocks.
  final List<String> bullets;

  /// Custom back action. Defaults to pop-or-home.
  final VoidCallback? onBack;

  void _back(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _back(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appBarTitle,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LockBadge(large: true),
                      const SizedBox(height: 20),
                      Text(
                        heading,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
                      ),
                      if (bullets.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRO İLE NELER AÇILIR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ink3,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final b in bullets)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          size: 16, color: AppColors.sage),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          b,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: ink2,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _UpgradeButton(
                        onUpgrade: () => goToSubscription(context),
                        expand: true,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => _back(context),
                        child: Text(
                          'Şimdi değil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ink3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared pieces
// ─────────────────────────────────────────────────────────────────────────────

/// Amber lock chip — amber is PoM's "attention" accent (never red).
class _LockBadge extends StatelessWidget {
  const _LockBadge({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 72.0 : 52.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.amberWash,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
      ),
      child: Icon(
        Icons.workspace_premium_rounded,
        color: AppColors.amberDeep,
        size: large ? 34 : 26,
      ),
    );
  }
}

/// Primary "Pro'ya Geç" call-to-action. Matches the subscription screen's blue
/// filled-button styling.
class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    required this.onUpgrade,
    this.expand = false,
  });

  final VoidCallback onUpgrade;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onUpgrade,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.bolt_rounded, size: 18),
      label: const Text(
        'Pro\'ya Geç',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, height: 52, child: button);
  }
}
