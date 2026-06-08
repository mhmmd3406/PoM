import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/surveys_provider.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class SurveyAnswerScreen extends ConsumerStatefulWidget {
  const SurveyAnswerScreen({
    super.key,
    required this.surveyId,
    this.canClose = true,
    this.showSkip = false,
    this.onSkip,
  });

  final String surveyId;

  /// Whether the top-right close (X) is shown. Gate surveys in mandatory mode
  /// set this false so the screen cannot be dismissed without completing.
  final bool canClose;

  /// Whether an "Atla" (skip) action is shown instead of the close (X).
  final bool showSkip;

  /// Invoked when the user taps "Atla". Falls back to a safe close if null.
  final VoidCallback? onSkip;

  @override
  ConsumerState<SurveyAnswerScreen> createState() =>
      _SurveyAnswerScreenState();
}

enum _LoadState { loading, alreadyAnswered, ready, submitting, done, error }

class _SurveyAnswerScreenState extends ConsumerState<SurveyAnswerScreen> {
  _LoadState _loadState = _LoadState.loading;
  SurveyModel? _survey;
  String? _errorMsg;

  int _step = 0;
  final Map<int, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(surveysRepositoryProvider);
    final user = ref.read(currentUserProvider);

    try {
      final survey = await repo.getSurvey(widget.surveyId);
      if (survey == null) {
        setState(() {
          _loadState = _LoadState.error;
          _errorMsg = 'Anket bulunamadı.';
        });
        return;
      }

      // "Already answered" is tracked on the user's own document
      // (users/{uid}.answeredSurveyIds), loaded at sign-in — the app no longer
      // reads survey_responses (firestore.rules restrict that to admins /
      // company members, which caused the F5 PERMISSION_DENIED).
      if (user != null && user.answeredSurveyIds.contains(widget.surveyId)) {
        setState(() => _loadState = _LoadState.alreadyAnswered);
        return;
      }

      setState(() {
        _survey = survey;
        _loadState = _LoadState.ready;
      });
    } catch (e) {
      setState(() {
        _loadState = _LoadState.error;
        _errorMsg = 'Anket yüklenemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _submit() async {
    final survey = _survey;
    final user = ref.read(currentUserProvider);
    if (survey == null) return;

    setState(() => _loadState = _LoadState.submitting);

    // Debug-bypass: the in-memory test user's uid is not the (anonymous) Firebase
    // session uid, so submitResponse's users/{uid}.answeredSurveyIds write is
    // denied and the batch fails. Simulate success locally — same approach as the
    // check-in flow — so the survey/gate is fully demoable without a real account.
    if (kDebugMode && AppConstants.debugBypassAuth) {
      if (user != null && !user.answeredSurveyIds.contains(survey.id)) {
        ref.read(authStateNotifierProvider.notifier).refreshUser(
              user.copyWith(
                answeredSurveyIds: [...user.answeredSurveyIds, survey.id],
              ),
            );
      }
      if (mounted) setState(() => _loadState = _LoadState.done);
      return;
    }

    try {
      final repo = ref.read(surveysRepositoryProvider);
      final hash = user != null ? hashUserId(user.uid) : 'anonymous';

      // Build answers map: questionId → answer value
      final answersMap = <String, dynamic>{};
      for (var i = 0; i < survey.questions.length; i++) {
        final q = survey.questions[i];
        if (_answers.containsKey(i)) {
          answersMap[q.id] = _answers[i];
        }
      }

      await repo.submitResponse(
        surveyId: survey.id,
        companyId: survey.companyId,
        userIdHash: hash,
        uid: user?.uid,
        answers: answersMap,
      );

      // Reflect the answer in the in-memory user model immediately so the
      // survey lists + the already-answered guard update without a re-read
      // (currentUserProvider is loaded once at sign-in, not streamed).
      if (user != null && !user.answeredSurveyIds.contains(survey.id)) {
        ref.read(authStateNotifierProvider.notifier).refreshUser(
              user.copyWith(
                answeredSurveyIds: [...user.answeredSurveyIds, survey.id],
              ),
            );
      }

      setState(() => _loadState = _LoadState.done);
    } catch (_) {
      setState(() => _loadState = _LoadState.ready);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yanıt gönderilemedi. Lütfen tekrar deneyin.'),
          ),
        );
      }
    }
  }

  void _answer(dynamic value) => setState(() => _answers[_step] = value);

  void _next() {
    final total = _survey?.questions.length ?? 0;
    if (_step >= total - 1) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  /// Pops if there is a route to pop, otherwise routes home — safe for both the
  /// pushed /survey/:id/answer route and the gate intercept (which uses go()).
  void _safeClose() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_loadState) {
      _LoadState.loading || _LoadState.submitting => _LoadingView(
          message: _loadState == _LoadState.submitting
              ? 'Yanıtlar kaydediliyor…'
              : 'Anket yükleniyor…',
        ),
      _LoadState.done => _ThankYouScreen(
          survey: _survey,
          onHome: () => context.go('/'),
        ),
      _LoadState.alreadyAnswered => _AlreadyAnsweredScreen(
          onHome: () => context.go('/'),
        ),
      _LoadState.error => _ErrorView(
          message: _errorMsg ?? 'Bir hata oluştu.',
          onRetry: () {
            setState(() => _loadState = _LoadState.loading);
            _load();
          },
        ),
      _LoadState.ready => _buildQuestion(context),
    };
  }

  Widget _buildQuestion(BuildContext context) {
    final survey = _survey!;
    final questions = survey.questions;
    final total = questions.length;
    final q = questions[_step];
    final answered = _answers[_step];
    final isLast = _step == total - 1;
    final progress = (_step + 1) / total;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final sourceLabel =
        survey.isAdminSurvey ? 'PoM Platform' : 'Şirketiniz';

    // NOTE: This screen is built entirely inside `body` with custom
    // (GestureDetector) buttons and a FractionallySizedBox progress bar —
    // NOT Scaffold.appBar/bottomNavigationBar with Material buttons. On this
    // Flutter version a Material ButtonStyleButton (or LinearProgressIndicator)
    // placed as a non-flex sibling to an Expanded silently aborts the parent
    // layout, leaving the whole question body blank. See project notes.
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (custom) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _back,
                    child: Icon(Icons.arrow_back_rounded, size: 22, color: ink2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SORU ${_step + 1} / $total  •  ${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ink3,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Container(
                            height: 4,
                            color: isDark
                                ? AppColors.darkBgAlt
                                : AppColors.lightBgAlt,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(color: AppColors.blue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (widget.showSkip)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onSkip ?? _safeClose,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text('Atla',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ink3)),
                      ),
                    )
                  else if (widget.canClose)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _safeClose,
                      child: Icon(Icons.close_rounded, size: 20, color: ink3),
                    )
                  else
                    const SizedBox(width: 20),
                ],
              ),
            ),

            // ── Scrollable content ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
            // Survey label + anon note
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBgAlt
                        : AppColors.lightBgAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${survey.title} · $sourceLabel',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: ink3,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.sage,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Anonim kaydedilir',
                    style: TextStyle(fontSize: 11, color: ink3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              q.text,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: ink,
                height: 1.25,
                letterSpacing: -0.5,
              ),
            ),
            if (q.hint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(q.hint,
                  style: TextStyle(fontSize: 14, color: ink2, height: 1.4)),
            ],
            const SizedBox(height: 28),

            // Input widget based on question type
            _buildInput(q, answered, isDark, border, ink, ink2, ink3),
                ],
              ),
            ),

            // ── Bottom bar (custom buttons) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _step > 0 ? _back : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              size: 16, color: _step > 0 ? ink2 : ink3),
                          const SizedBox(width: 4),
                          Text('Geri',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _step > 0 ? ink2 : ink3)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: answered != null ? _next : null,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: answered != null
                            ? AppColors.blue
                            : (isDark
                                ? AppColors.darkBgAlt
                                : AppColors.lightBgAlt),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isLast ? 'Gönder' : 'İleri →',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: answered != null ? Colors.white : ink3),
                      ),
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

  Widget _buildInput(
    SurveyQuestion q,
    dynamic answered,
    bool isDark,
    Color border,
    Color ink,
    Color ink2,
    Color ink3,
  ) {
    switch (q.type) {
      case SurveyQuestionType.emoji5:
        return _Emoji5Input(
          selected: answered as int?,
          onSelect: (v) {
            _answer(v);
            _next();
          },
          isDark: isDark,
          border: border,
        );
      case SurveyQuestionType.yesno:
        return _YesNoInput(
          selected: answered as bool?,
          onSelect: (v) {
            _answer(v);
            _next();
          },
          isDark: isDark,
          border: border,
        );
      case SurveyQuestionType.scale10:
        return _Scale10Input(
          selected: answered as int?,
          onSelect: (v) {
            _answer(v);
            _next();
          },
          isDark: isDark,
          border: border,
          ink: ink,
          ink2: ink2,
          ink3: ink3,
        );
      case SurveyQuestionType.scale5:
        return _Scale5Input(
          selected: answered as int?,
          onSelect: (v) {
            _answer(v);
            _next();
          },
          isDark: isDark,
          border: border,
          ink: ink,
          ink3: ink3,
        );
      case SurveyQuestionType.trueFalse:
        return _TrueFalseInput(
          selected: answered as bool?,
          onSelect: (v) {
            _answer(v);
            _next();
          },
          isDark: isDark,
          border: border,
        );
      case SurveyQuestionType.text:
        return _TextInput(
          value: answered as String? ?? '',
          onChanged: _answer,
          isDark: isDark,
          border: border,
          ink: ink,
          ink3: ink3,
        );
    }
  }
}

// ─── Loading view ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: ink3)),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(message,
                  style: TextStyle(color: ink),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: onRetry, child: const Text('Tekrar Dene')),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Already answered ─────────────────────────────────────────────────────────

class _AlreadyAnsweredScreen extends StatelessWidget {
  const _AlreadyAnsweredScreen({required this.onHome});
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.sageWash,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.sage, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Zaten Yanıtladın',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu anketi daha önce yanıtladın. Her ankete yalnızca bir kez katılabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: ink2, height: 1.55),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onHome,
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text('Ana Sayfa',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Thank you screen ─────────────────────────────────────────────────────────

class _ThankYouScreen extends StatelessWidget {
  const _ThankYouScreen({required this.survey, required this.onHome});
  final SurveyModel? survey;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.sageWash,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.sage, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Teşekkürler!',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${survey?.questionCount ?? 0} soruyu yanıtladın. Yanıtların anonim olarak kaydedildi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: ink2, height: 1.55),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBgAlt
                        : AppColors.lightBgAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 16, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu anket sonuçları minimum ${survey?.minNThreshold ?? 5} kişi cevaplandıktan sonra görüntülenebilir.',
                          style: TextStyle(
                              fontSize: 12.5, color: ink2, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onHome,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Ana Sayfa',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 5-emoji input ────────────────────────────────────────────────────────────

const _kEmojis = ['😞', '😕', '😐', '🙂', '😄'];
const _kEmojiLabels = ['Çok kötü', 'Kötü', 'Orta', 'İyi', 'Harika'];

class _Emoji5Input extends StatelessWidget {
  const _Emoji5Input({
    required this.selected,
    required this.onSelect,
    required this.isDark,
    required this.border,
  });

  final int? selected;
  final ValueChanged<int> onSelect;
  final bool isDark;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(5, (i) {
            final isSelected = selected == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.blue.withValues(alpha: 0.1)
                        : (isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.blue : border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_kEmojis[i],
                          style: const TextStyle(fontSize: 28)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        if (selected != null)
          Text(
            _kEmojiLabels[selected!],
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.blue,
            ),
          ),
      ],
    );
  }
}

// ─── Yes/No input ─────────────────────────────────────────────────────────────

class _YesNoInput extends StatelessWidget {
  const _YesNoInput({
    required this.selected,
    required this.onSelect,
    required this.isDark,
    required this.border,
  });

  final bool? selected;
  final ValueChanged<bool> onSelect;
  final bool isDark;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BigChoiceButton(
          label: 'Evet',
          isSelected: selected == true,
          color: AppColors.sage,
          onTap: () => onSelect(true),
          isDark: isDark,
          border: border,
        ),
        const SizedBox(width: 12),
        _BigChoiceButton(
          label: 'Hayır',
          isSelected: selected == false,
          color: AppColors.rose,
          onTap: () => onSelect(false),
          isDark: isDark,
          border: border,
        ),
      ],
    );
  }
}

class _BigChoiceButton extends StatelessWidget {
  const _BigChoiceButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
    required this.isDark,
    required this.border,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 72,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : border,
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? color
                  : (isDark ? AppColors.darkInk2 : AppColors.lightInk2),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Scale 1–5 input ─────────────────────────────────────────────────────────

class _Scale5Input extends StatelessWidget {
  const _Scale5Input({
    required this.selected,
    required this.onSelect,
    required this.isDark,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final int? selected;
  final ValueChanged<int> onSelect;
  final bool isDark;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 · HİÇ',
                style: TextStyle(
                    fontSize: 11, color: ink3, fontWeight: FontWeight.w600)),
            Text('5 · TAMAMEN',
                style: TextStyle(
                    fontSize: 11, color: ink3, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: List.generate(5, (i) {
            final val = i + 1;
            final isSelected = selected == val;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
                child: GestureDetector(
                  onTap: () => onSelect(val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.blue
                          : (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface),
                      border: Border.all(
                        color: isSelected ? AppColors.blue : border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$val',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : ink,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── True/False input ────────────────────────────────────────────────────────

class _TrueFalseInput extends StatelessWidget {
  const _TrueFalseInput({
    required this.selected,
    required this.onSelect,
    required this.isDark,
    required this.border,
  });

  final bool? selected;
  final ValueChanged<bool> onSelect;
  final bool isDark;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BigChoiceButton(
          label: 'Doğru',
          isSelected: selected == true,
          color: AppColors.sage,
          onTap: () => onSelect(true),
          isDark: isDark,
          border: border,
        ),
        const SizedBox(width: 12),
        _BigChoiceButton(
          label: 'Yanlış',
          isSelected: selected == false,
          color: AppColors.rose,
          onTap: () => onSelect(false),
          isDark: isDark,
          border: border,
        ),
      ],
    );
  }
}

// ─── Scale 0–10 / NPS input ───────────────────────────────────────────────────

class _Scale10Input extends StatelessWidget {
  const _Scale10Input({
    required this.selected,
    required this.onSelect,
    required this.isDark,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final int? selected;
  final ValueChanged<int> onSelect;
  final bool isDark;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 · HİÇ',
                style: TextStyle(
                    fontSize: 11,
                    color: ink3,
                    fontWeight: FontWeight.w600)),
            Text('10 · KESİNLİKLE',
                style: TextStyle(
                    fontSize: 11,
                    color: ink3,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(11, (i) {
            final isSelected = selected == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.blue
                      : (isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface),
                  border: Border.all(
                    color: isSelected ? AppColors.blue : border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$i',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : ink,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Free text input ──────────────────────────────────────────────────────────

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      maxLines: 4,
      style: TextStyle(fontSize: 16, color: widget.ink),
      decoration: InputDecoration(
        hintText: 'Yanıtını buraya yaz…',
        hintStyle: TextStyle(color: widget.ink3),
        filled: true,
        fillColor: widget.isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: widget.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: widget.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
      ),
    );
  }
}

// ─── Min-N lock screen (kept for route compatibility) ─────────────────────────

class SurveyMinNLockScreen extends StatelessWidget {
  const SurveyMinNLockScreen({
    super.key,
    this.current = 8,
    this.minRequired = 15,
    this.surveyTitle = '',
  });

  final int current;
  final int minRequired;
  final String surveyTitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final bgAlt = isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final amberCol = isDark ? AppColors.amberDark : AppColors.amber;
    final amberBg = isDark ? AppColors.amberSoftDark : AppColors.amberWash;
    final progress = (current / minRequired).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          surveyTitle,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration:
                          BoxDecoration(color: amberBg, shape: BoxShape.circle),
                      child: Icon(Icons.lock_rounded,
                          size: 34, color: amberCol),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sonuçlar Kilitli',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Anonim sonuçları görüntülemek için en az $minRequired katılımcı gereklidir. Şu an $current kişi yanıtladı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$current / $minRequired katılımcı',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ink3,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: amberCol,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: bgAlt,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(amberCol),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: AppColors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gizliliğinizi korumak için minimum $minRequired yanıt eşiği uygulanmaktadır.',
                        style: TextStyle(
                            fontSize: 12.5, color: ink2, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border),
                    foregroundColor: ink2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Geri Dön',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
