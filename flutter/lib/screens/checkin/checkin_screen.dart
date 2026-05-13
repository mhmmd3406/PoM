import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

const _metrics = [
  (key: 'salary', label: 'Salary', icon: '💰'),
  (key: 'benefits', label: 'Benefits', icon: '🏥'),
  (key: 'workModel', label: 'Work Model', icon: '🏠'),
  (key: 'culture', label: 'Culture', icon: '🤝'),
  (key: 'wlb', label: 'Work-Life Balance', icon: '⚖️'),
];

const _emojis = ['😞', '😕', '😐', '😊', '🤩'];

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final Map<String, int> _ratings = {
    'salary': 0,
    'benefits': 0,
    'workModel': 0,
    'culture': 0,
    'wlb': 0,
  };
  bool _submitting = false;

  bool get _isComplete => _ratings.values.every((v) => v > 0);

  Future<void> _submit() async {
    if (!_isComplete) return;
    setState(() => _submitting = true);

    try {
      final result = await ref.read(firestoreServiceProvider).submitCheckin(
            CheckinRatings(
              salary: _ratings['salary']!,
              benefits: _ratings['benefits']!,
              workModel: _ratings['workModel']!,
              culture: _ratings['culture']!,
              wlb: _ratings['wlb']!,
            ),
          );

      if (!mounted) return;
      _showSuccessSheet(result.creditsAwarded, result.newStreak);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }

  void _showSuccessSheet(int credits, int streak) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        creditsEarned: credits,
        streak: streak,
        onDone: () {
          Navigator.pop(context);
          context.go('/home');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Weekly Check-in'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _metrics.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) {
                  final m = _metrics[i];
                  return _MetricCard(
                    icon: m.icon,
                    label: m.label,
                    rating: _ratings[m.key]!,
                    onRate: (r) => setState(() => _ratings[m.key] = r),
                  ).animate(delay: (i * 60).ms).fadeIn().slideX(begin: 0.15, end: 0);
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: AnimatedOpacity(
                  opacity: _isComplete ? 1 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: (_isComplete && !_submitting) ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Submit Check-in  +2 credits'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.rating,
    required this.onRate,
  });
  final String icon;
  final String label;
  final int rating;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (i) {
                  final val = i + 1;
                  final selected = rating == val;
                  final color = AppColors.ratingColors[i];
                  return GestureDetector(
                    onTap: () => onRate(val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withOpacity(0.2)
                            : AppColors.bg3,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? color : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _emojis[i],
                          style: TextStyle(
                              fontSize: selected ? 26 : 22),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      );
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({
    required this.creditsEarned,
    required this.streak,
    required this.onDone,
  });
  final int creditsEarned;
  final int streak;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: const TextStyle(fontSize: 56))
                .animate()
                .scale(begin: const Offset(0, 0), duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text('Check-in complete!',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '+$creditsEarned credits earned  •  $streak week streak 🔥',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.positive),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: onDone, child: const Text('See My Insights')),
          ],
        ),
      );
}
