import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    if (state.currentStep < CheckinFlowState.totalSteps - 1) {
      notifier.nextStep();
      _goToPage(state.currentStep + 1);
    } else {
      final result = await notifier.submit();
      if (result != null && mounted) {
        _showSuccessSheet();
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

  void _showSuccessSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final sageDeep = isDark ? AppColors.sageDeepDark : AppColors.sageDeep;
    final sageWash = isDark ? AppColors.sageWashDark : AppColors.sageWash;
    final amberWash = isDark ? AppColors.amberSoftDark : AppColors.amberWash;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Check circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.sage,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sage.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Tebrikler!',
              style: TextStyle(
                fontFamily: 'BricolageGrotesque',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu haftanın check-in\'i kaydedildi.\nBir sonraki soru 7 gün sonra.',
              style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Strength / attention cards
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sageWash,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Text('🏆', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        '🤝 Takım Uyumu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: amberWash,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Text('⚠️', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        '😌 İş Stresi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/insights');
                },
                child: const Text('İçgörüleri Gör'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/');
                },
                child: const Text('Ana Sayfa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cooldownAsync = ref.watch(checkinCooldownProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

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

// ─── Cooldown state ───────────────────────────────────────────────────────────

class _CooldownState extends StatelessWidget {
  const _CooldownState({required this.remaining});
  final Duration remaining;

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return '$days gün $hours saat';
    if (hours > 0) return '$hours saat $minutes dakika';
    return '$minutes dakika';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final parts = [
      _CountdownPart(value: remaining.inDays, label: 'gün'),
      _CountdownPart(value: remaining.inHours % 24, label: 'saat'),
      _CountdownPart(value: remaining.inMinutes % 60, label: 'dk'),
    ];

    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
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
                    style: TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bir sonraki check-in\'i şu kadar süre\nsonra yapabilirsin:',
                    style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: parts
                          .expand((p) => [
                                _CountdownCell(part: p, ink: ink, ink3: ink3),
                                if (p != parts.last)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      ':',
                                      style: TextStyle(
                                        fontSize: 24,
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

class _CountdownPart {
  const _CountdownPart({required this.value, required this.label});
  final int value;
  final String label;
}

class _CountdownCell extends StatelessWidget {
  const _CountdownCell({required this.part, required this.ink, required this.ink3});
  final _CountdownPart part;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          part.value.toString().padLeft(2, '0'),
          style: TextStyle(
            fontFamily: 'BricolageGrotesque',
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: ink,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          part.label.toUpperCase(),
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
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
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
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
                    final currentStep = state.currentStep;
                    ref.read(checkinFlowProvider.notifier).selectAnswer(val);
                    if (currentStep < CheckinFlowState.totalSteps - 1) {
                      Future.delayed(const Duration(milliseconds: 380), onNext);
                    }
                  },
                ),
              );
            },
          ),
        ),

        // Error message
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
                          color: Theme.of(context).colorScheme.onErrorContainer),
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
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state.isCurrentStepAnswered && !state.isSubmitting
                          ? onNext
                          : null,
                      child: state.isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Tamamla'),
                    ),
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
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
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
