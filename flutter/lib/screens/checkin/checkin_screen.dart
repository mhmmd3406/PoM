import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/emoji_rating_picker.dart';

// ── Step definition ────────────────────────────────────────────────────────

class _Step {
  const _Step(this.key, this.name, this.question, this.icon, this.gradient, this.accent);
  final String key;
  final String name;
  final String question;
  final String icon;
  final List<Color> gradient;
  final Color accent;
}

const _steps = [
  _Step('salary', 'Salary', "How's your compensation?", '💰',
      [Color(0xFF0D0C2B), Color(0xFF1A1040)], Color(0xFF7C5CFC)),
  _Step('benefits', 'Benefits', 'Health, perks & extras?', '🎁',
      [Color(0xFF0A190A), Color(0xFF0D2B18)], Color(0xFF34D399)),
  _Step('work_model', 'Work Model', 'Office, hybrid or remote?', '🏠',
      [Color(0xFF091220), Color(0xFF0C1E38)], Color(0xFF60A5FA)),
  _Step('culture', 'Culture', 'Team, values & leadership?', '🤝',
      [Color(0xFF200A14), Color(0xFF380D1E)], Color(0xFFF87171)),
  _Step('wlb', 'Work-Life Balance', 'Time for yourself?', '⚖️',
      [Color(0xFF14082A), Color(0xFF22103F)], Color(0xFFA78BFA)),
];

// ── Screen ─────────────────────────────────────────────────────────────────

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _ctrl = PageController();
  final _ratings = <String, int>{};
  int _page = 0;
  bool _submitting = false;
  bool _submitted = false;
  int _creditsEarned = 0;
  String? _error;

  bool get _isReview => _page == _steps.length;
  bool get _canProceed =>
      _isReview || _ratings.containsKey(_steps[_page].key);

  List<Color> get _bg => _isReview
      ? const [Color(0xFF0D0D1A), Color(0xFF13132A)]
      : _steps[_page].gradient;

  void _setRating(int v) => setState(() {
        _ratings[_steps[_page].key] = v;
        _error = null;
      });

  void _next() {
    if (!_canProceed) {
      HapticFeedback.vibrate();
      return;
    }
    if (_isReview) {
      _submit();
      return;
    }
    HapticFeedback.lightImpact();
    _ctrl.nextPage(duration: 420.ms, curve: Curves.easeInOutCubic);
  }

  void _back() {
    if (_page == 0) {
      context.pop();
      return;
    }
    _ctrl.previousPage(duration: 350.ms, curve: Curves.easeInOutCubic);
  }

  Future<void> _submit() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ref.read(firestoreServiceProvider).submitCheckin(
            CheckinRatings(
              salary: _ratings['salary']!,
              benefits: _ratings['benefits']!,
              workModel: _ratings['work_model']!,
              culture: _ratings['culture']!,
              wlb: _ratings['wlb']!,
            ),
          );
      await Future.delayed(120.ms);
      HapticFeedback.heavyImpact();
      setState(() {
        _submitting = false;
        _submitted = true;
        _creditsEarned = res.creditsAwarded;
      });
      await Future.delayed(2600.ms);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString().contains('already checked')
            ? 'Already checked in this week. Come back in 7 days.'
            : 'Something went wrong — please try again.';
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _page == 0,
        onPopInvokedWithResult: (_, __) {
          if (_page > 0) _back();
        },
        child: Scaffold(
          body: AnimatedContainer(
            duration: 520.ms,
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _bg,
              ),
            ),
            child: SafeArea(
              child: _submitted
                  ? _SuccessView(credits: _creditsEarned)
                  : _buildFlow(),
            ),
          ),
        ),
      );

  Widget _buildFlow() => Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _ctrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                ..._steps.map((s) => _MetricPage(
                      step: s,
                      value: _ratings[s.key],
                      onChanged: _setRating,
                    )),
                _ReviewPage(ratings: _ratings, error: _error),
              ],
            ),
          ),
          _buildFooter(),
        ],
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white54),
              onPressed: _back,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  final active = !_isReview && i == _page;
                  final done = i < _page || _isReview;
                  return AnimatedContainer(
                    duration: 350.ms,
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.accent
                          : active
                              ? _steps[_page].accent
                              : Colors.white18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Text(
              _isReview ? 'Review' : '${_page + 1} / ${_steps.length}',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _buildFooter() {
    final accent = _isReview ? AppColors.accent : _steps[_page].accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: AnimatedContainer(
        duration: 250.ms,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: _canProceed
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.38),
                    blurRadius: 22,
                    offset: const Offset(0, 7),
                  )
                ]
              : [],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _submitting ? null : _next,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _canProceed ? accent : Colors.white.withOpacity(0.08),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white10,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isReview ? 'Submit Pulse  ⚡' : 'Continue',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2),
                      ),
                      if (!_isReview) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Metric page ───────────────────────────────────────────────────────────

class _MetricPage extends StatelessWidget {
  const _MetricPage(
      {required this.step, required this.value, required this.onChanged});
  final _Step step;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
        child: Column(
          children: [
            Text(step.icon, style: const TextStyle(fontSize: 54))
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(
                    begin: const Offset(0.4, 0.4),
                    curve: Curves.elasticOut,
                    duration: 600.ms),
            const SizedBox(height: 14),
            Text(
              step.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.15, curve: Curves.easeOut),
            const SizedBox(height: 6),
            Text(
              step.question,
              style: TextStyle(color: Colors.white.withOpacity(0.48), fontSize: 15),
            ).animate().fadeIn(delay: 110.ms),
            const SizedBox(height: 44),
            EmojiRatingPicker(
              value: value,
              onChanged: onChanged,
              accentColor: step.accent,
            ).animate().fadeIn(delay: 170.ms).slideY(begin: 0.08),
          ],
        ),
      );
}

// ── Review page ───────────────────────────────────────────────────────────

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.ratings, required this.error});
  final Map<String, int> ratings;
  final String? error;

  static const _emojis = ['😫', '😕', '😐', '😊', '🤩'];
  static const _labels = ['Struggling', 'Below Avg', "It's OK", 'Pretty Good', 'Excellent!'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Your Pulse', style: Theme.of(context).textTheme.displayMedium)
                .animate()
                .fadeIn()
                .slideY(begin: 0.2),
            const SizedBox(height: 4),
            Text(
              'Confirm before submitting — go back to change any rating.',
              style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 13),
            ).animate().fadeIn(delay: 70.ms),
            const SizedBox(height: 22),
            ...List.generate(
              _steps.length,
              (i) => _ReviewRow(
                step: _steps[i],
                rating: ratings[_steps[i].key],
                i: i,
              ),
            ),
            const SizedBox(height: 20),
            // Credit reward card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.positive.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.positive.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('✦',
                      style: TextStyle(color: AppColors.positive, fontSize: 22)),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+2 credits earned',
                          style: TextStyle(
                              color: AppColors.positive,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text('Weekly pulse bonus',
                          style: TextStyle(color: AppColors.positive, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.verified_rounded,
                      color: AppColors.positive.withOpacity(0.65), size: 22),
                ],
              ),
            ).animate().fadeIn(delay: 340.ms),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.negative.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.negative.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.negative, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error!,
                          style: const TextStyle(
                              color: AppColors.negative, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.step, required this.rating, required this.i});
  final _Step step;
  final int? rating;
  final int i;

  static const _emojis = ['😫', '😕', '😐', '😊', '🤩'];
  static const _labels = ['Struggling', 'Below Avg', "It's OK", 'Pretty Good', 'Excellent!'];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(step.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(step.name,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const Spacer(),
            if (rating != null) ...[
              Text(_emojis[rating! - 1], style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: step.accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_labels[rating! - 1],
                    style: TextStyle(
                        color: step.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ] else
              Text('—',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.25), fontSize: 14)),
          ],
        )
            .animate()
            .fadeIn(delay: (i * 55 + 100).ms)
            .slideX(begin: 0.08, curve: Curves.easeOut),
      );
}

// ── Success view ──────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.credits});
  final int credits;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 90))
                .animate()
                .scale(
                    begin: const Offset(0.1, 0.1),
                    duration: 700.ms,
                    curve: Curves.elasticOut)
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 28),
            const Text('Pulse Submitted!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5))
                .animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.2, curve: Curves.easeOut),
            const SizedBox(height: 10),
            Text('+$credits ✦ credits earned',
                    style: const TextStyle(
                        color: AppColors.positive,
                        fontSize: 20,
                        fontWeight: FontWeight.w600))
                .animate()
                .fadeIn(delay: 650.ms)
                .slideY(begin: 0.15),
            const SizedBox(height: 8),
            const Text('Your voice shapes the industry.',
                    style: TextStyle(color: Colors.white38, fontSize: 14))
                .animate()
                .fadeIn(delay: 900.ms),
            const SizedBox(height: 52),
            Wrap(
              spacing: 8,
              children: List.generate(
                9,
                (i) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.ratingColors[i % 5].withOpacity(0.75),
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(delay: (740 + i * 65).ms)
                    .scale(
                        begin: const Offset(0, 0),
                        curve: Curves.elasticOut,
                        duration: 500.ms)
                    .fadeIn(),
              ),
            ),
          ],
        ),
      );
}
