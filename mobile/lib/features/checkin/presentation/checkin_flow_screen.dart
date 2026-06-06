import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/checkin_provider.dart';
import 'checkin_step_widget.dart';

class CheckinFlowScreen extends ConsumerStatefulWidget {
  const CheckinFlowScreen({super.key});

  @override
  ConsumerState<CheckinFlowScreen> createState() => _CheckinFlowScreenState();
}

class _CheckinFlowScreenState extends ConsumerState<CheckinFlowScreen> {
  final PageController _pageController = PageController();
  bool _showSuccess = false;
  Map<String, double>? _resultScores;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkinFlowProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _handleNext() async {
    final notifier = ref.read(checkinFlowProvider.notifier);
    final state = ref.read(checkinFlowProvider);

    if (!state.isCurrentStepAnswered) return;
    // Guard against double submission: rapid taps on the final emoji schedule
    // multiple delayed onNext calls, and submit() must run at most once.
    if (state.isSubmitting || state.isComplete) return;

    if (state.currentStep < CheckinFlowState.totalSteps - 1) {
      notifier.nextStep();
      _goToPage(state.currentStep + 1);
    } else {
      final result = await notifier.submit();
      if (result != null && mounted) {
        setState(() {
          _showSuccess = true;
          _resultScores = {
                'Genel Ruh Hali': result.overallMood.toDouble(),
                'İş Stresi': result.workStress.toDouble(),
                'Takım Uyumu': result.teamHarmony.toDouble(),
                'Kişisel Gelişim': result.personalGrowth.toDouble(),
                'İş-Yaşam Dengesi': result.workLifeBalance.toDouble(),
              };
        });
      }
    }
  }

  void _handlePrevious() {
    final state = ref.read(checkinFlowProvider);
    if (state.currentStep > 0) {
      ref.read(checkinFlowProvider.notifier).previousStep();
      _goToPage(state.currentStep - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cooldownAsync = ref.watch(checkinCooldownProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    if (_showSuccess) {
      return _SuccessScreen(
        scores: _resultScores ?? {},
        isDark: isDark,
        onInsights: () => context.go('/insights'),
        onHome: () => context.go('/'),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: cooldownAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (remaining) {
            if (remaining > Duration.zero) {
              return _CooldownState(remaining: remaining);
            }
            return _CheckinFlow(
              pageController: _pageController,
              onNext: _handleNext,
              onPrevious: _handlePrevious,
            );
          },
        ),
      ),
    );
  }
}

// ─── Success / Celebration screen ─────────────────────────────────────────────

class _SuccessScreen extends StatefulWidget {
  const _SuccessScreen({
    required this.scores,
    required this.isDark,
    required this.onInsights,
    required this.onHome,
  });

  final Map<String, double> scores;
  final bool isDark;
  final VoidCallback onInsights;
  final VoidCallback onHome;

  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final sageDeep = isDark ? AppColors.sageDeepDark : AppColors.sageDeep;
    final sageWash = isDark ? AppColors.sageWashDark : AppColors.sageWash;
    final amberWash = isDark ? AppColors.amberSoftDark : AppColors.amberWash;

    // Compute avg from scores
    final avg = widget.scores.isEmpty
        ? 4.0
        : widget.scores.values.reduce((a, b) => a + b) /
            widget.scores.length;

    // Normalized for radar
    final _dimensionOrder = [
      'overallMood',
      'workStress',
      'teamHarmony',
      'personalGrowth',
      'workLifeBalance',
    ];
    final normalized = _dimensionOrder
        .map((k) => ((widget.scores[k] ?? 3.0) / 5.0).clamp(0.0, 1.0))
        .toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Checkmark circle with confetti dots
              Stack(
                alignment: Alignment.center,
                children: [
                  // Confetti dots
                  AnimatedBuilder(
                    animation: _confettiCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ConfettiPainter(
                          progress: _confettiCtrl.value,
                          isDark: isDark,
                        ),
                        child: const SizedBox(width: 160, height: 160),
                      );
                    },
                  ),
                  // Green circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sage.withValues(alpha: 0.30),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 36),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                'Teşekkürler!',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu haftanın check-in\'i kaydedildi. Bir sonraki soru 7 gün sonra.',
                style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Score card with radar
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    // Radar
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _RadarPainter(
                          values: normalized,
                          color: AppColors.blue,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BU HAFTAKİ DURUMUN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ink3,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                avg.toStringAsFixed(1),
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                  height: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text('/5',
                                    style:
                                        TextStyle(fontSize: 13, color: ink3)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '↑ Geçen haftaya göre +0.3',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sageDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // EN GÜÇLÜ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sageWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'EN GÜÇLÜ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sageDeep,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🤝 Takım Uyumu · 4.5/5',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // DİKKAT EDİLECEK
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: amberWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'DİKKAT EDİLECEK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amberDeep,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '😌 İş Stresi · 3.5/5',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Primary CTA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onInsights,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'İçgörüleri Gör',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary
              GestureDetector(
                onTap: widget.onHome,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Ana Sayfa',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Confetti painter ─────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.isDark});
  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = Random(42);
    final colors = [
      AppColors.sage,
      AppColors.blue,
      AppColors.amber,
      AppColors.rose,
    ];
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 2 * pi / 12) + rng.nextDouble() * 0.4;
      final dist = 55 + rng.nextDouble() * 20;
      final r = dist * progress;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      paint.color =
          colors[i % colors.length].withValues(alpha: 1.0 - progress * 0.6);
      canvas.drawCircle(Offset(x, y), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ─── Radar painter (shared) ───────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.values,
    required this.color,
    required this.isDark,
  });

  final List<double> values;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;
    final n = values.length;

    final gridPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.15 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 3; ring++) {
      final path = Path();
      for (int j = 0; j < n; j++) {
        final angle = (j * 2 * pi / n) - pi / 2;
        final r = radius * ring / 3;
        final pt =
            Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
        if (j == 0) path.moveTo(pt.dx, pt.dy);
        else path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final dataPath = Path();
    final dots = <Offset>[];
    for (int i = 0; i < n; i++) {
      final angle = (i * 2 * pi / n) - pi / 2;
      final r = radius * values[i];
      final pt =
          Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      dots.add(pt);
      if (i == 0) dataPath.moveTo(pt.dx, pt.dy);
      else dataPath.lineTo(pt.dx, pt.dy);
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final pt in dots) {
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values || old.isDark != isDark;
}

// ─── Cooldown state ───────────────────────────────────────────────────────────

class _CooldownState extends StatelessWidget {
  const _CooldownState({required this.remaining});
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final parts = [
      (remaining.inDays, 'GÜN'),
      (remaining.inHours % 24, 'SAAT'),
      (remaining.inMinutes % 60, 'DK'),
    ];

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: ink2),
                ),
              ),
              const Spacer(),
              Text(
                'Haftalık Check-in',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: ink),
              ),
              const Spacer(),
              const SizedBox(width: 36),
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.blueWashDark : AppColors.blueWash,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 38,
                      color: isDark ? AppColors.blueDark : AppColors.blueDeep,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bu hafta tamamlandı',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bir sonraki check-in\'i şu kadar süre sonra yapabilirsin:',
                    style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Countdown cells
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: parts
                          .expand((p) => [
                                _CountdownCell(
                                    value: p.$1, label: p.$2, ink: ink, ink3: ink3),
                                if (p != parts.last)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text(
                                      ':',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w300,
                                        color: ink3,
                                      ),
                                    ),
                                  ),
                              ])
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/insights'),
                      child: const Text('İçgörüleri görüntüle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownCell extends StatelessWidget {
  const _CountdownCell({
    required this.value,
    required this.label,
    required this.ink,
    required this.ink3,
  });

  final int value;
  final String label;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: ink,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ink3,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Main check-in flow ───────────────────────────────────────────────────────

class _CheckinFlow extends ConsumerWidget {
  const _CheckinFlow({
    required this.pageController,
    required this.onNext,
    required this.onPrevious,
  });

  final PageController pageController;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinFlowProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final bgAlt = isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt;
    final isLastStep = state.currentStep == CheckinFlowState.totalSteps - 1;
    final progress = (state.currentStep + 1) / CheckinFlowState.totalSteps;

    return Column(
      children: [
        // Top bar — close + progress
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: ink2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ADIM ${state.currentStep + 1} / ${CheckinFlowState.totalSteps}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ink3,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        children: [
                          Container(height: 4, color: bgAlt),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 4,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.blue, AppColors.sage],
                                ),
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
          ),
        ),

        // Step pages
        Expanded(
          child: PageView.builder(
            controller: pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: CheckinFlowState.totalSteps,
            itemBuilder: (context, index) {
              final stepData = CheckinStepData.steps[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CheckinStepWidget(
                  stepData: stepData,
                  selectedValue: state.valueForStep(index),
                  onSelect: (val) {
                    ref.read(checkinFlowProvider.notifier).selectAnswer(val);
                    // Auto-advance after a short beat. On the final step this
                    // runs through onNext → _handleNext → submit(), which is the
                    // only thing that completes the check-in (fixes F1: the last
                    // step previously had no trigger and froze on "Kaydediliyor…").
                    Future.delayed(const Duration(milliseconds: 380), onNext);
                  },
                ),
              );
            },
          ),
        ),

        // Error
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Row(
            children: [
              if (state.currentStep > 0) ...[
                SizedBox(
                  width: 100,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Geri'),
                  ),
                ),
                if (isLastStep) const SizedBox(width: 12),
              ],
              if (!isLastStep)
                Expanded(
                  child: Text(
                    state.valueForStep(state.currentStep) == null
                        ? 'Bir emoji seç · otomatik geçer'
                        : 'Sonraki soruya geçiliyor…',
                    style: TextStyle(fontSize: 12, color: ink3),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isLastStep)
                Expanded(
                  child: Text(
                    state.valueForStep(state.currentStep) == null
                        ? 'Son soru!'
                        : 'Kaydediliyor…',
                    style: TextStyle(
                      fontSize: 13,
                      color: state.isCurrentStepAnswered
                          ? AppColors.sage
                          : ink3,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: state.currentStep > 0
                        ? TextAlign.right
                        : TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }
}
