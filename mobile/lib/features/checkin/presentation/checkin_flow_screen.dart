import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/checkin_provider.dart';
import 'checkin_step_widget.dart';

class CheckinFlowScreen extends ConsumerStatefulWidget {
  const CheckinFlowScreen({super.key});

  @override
  ConsumerState<CheckinFlowScreen> createState() => _CheckinFlowScreenState();
}

class _CheckinFlowScreenState extends ConsumerState<CheckinFlowScreen> {
  final PageController _pageController = PageController();
  bool _hasCheckedCooldown = false;

  @override
  void initState() {
    super.initState();
    // Reset flow on enter
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
      // Last step — submit
      final result = await notifier.submit();
      if (result != null && mounted) {
        _showSuccessDialog();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Text('✅', style: TextStyle(fontSize: 48)),
        title: const Text(
          'Tebrikler!',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Bu haftaki ruh hali anketin başarıyla kaydedildi. '
          'Bir sonraki anketi 7 gün sonra yapabilirsin.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/insights');
            },
            child: const Text('İçgörüleri Gör'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/');
            },
            child: const Text('Ana Sayfa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cooldownAsync = ref.watch(checkinCooldownProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık Check-in'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: cooldownAsync.when(
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⏳', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bir Sonraki Check-in',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bir sonraki ruh hali anketini yapabilmek için\n${_formatDuration(remaining)} beklemeniz gerekiyor.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Geri Dön'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Adım ${state.currentStep + 1} / ${CheckinFlowState.totalSteps}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '${((state.currentStep + 1) / CheckinFlowState.totalSteps * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (state.currentStep + 1) / CheckinFlowState.totalSteps,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
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
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Navigation buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Row(
            children: [
              if (state.currentStep > 0) ...[
                OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Geri'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 52),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isCurrentStepAnswered && !state.isSubmitting
                      ? onNext
                      : null,
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(
                          state.currentStep < CheckinFlowState.totalSteps - 1
                              ? 'Sonraki'
                              : 'Tamamla',
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }
}
