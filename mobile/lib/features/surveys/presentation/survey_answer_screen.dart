import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

// ─── Demo question data ────────────────────────────────────────────────────────

enum _QuestionType { emoji5, yesNo, trueFalse, scale5, scale10 }

class _Question {
  const _Question({required this.text, required this.type, this.hint = ''});
  final String text;
  final _QuestionType type;
  final String hint;
}

const _kDemoSurvey = _SurveyMeta(
  id: 'hibrit',
  title: 'Hibrit Çalışma Modeli',
  sender: 'İK',
  totalQuestions: 12,
);

const _kQuestions = [
  _Question(
    text: 'Hibrit modelden ne kadar memnunsunuz?',
    type: _QuestionType.emoji5,
    hint: 'Genel hissini emoji ile belirt.',
  ),
  _Question(
    text: 'Uzaktan çalışmayı tercih ederim.',
    type: _QuestionType.yesNo,
    hint: 'Bu sezgisel hissini bize aktar.',
  ),
  _Question(
    text: 'Hibrit çalışma verimliliğimi artırıyor.',
    type: _QuestionType.trueFalse,
    hint: 'Sezgisinle yanıtla.',
  ),
  _Question(
    text: 'Haftada kaç gün ofiste olmak istersiniz?',
    type: _QuestionType.scale5,
    hint: '1: hiç · 5: hep',
  ),
  _Question(
    text: "PoM'u bir arkadaşına önerme olasılığın?",
    type: _QuestionType.scale10,
    hint: '0–10 arası bir değer seç.',
  ),
  _Question(
    text: 'Ekiple iletişim yeterliliği nasıl?',
    type: _QuestionType.emoji5,
    hint: 'Genel hissini emoji ile belirt.',
  ),
  _Question(
    text: 'Evden çalışırken konsantre olabiliyorum.',
    type: _QuestionType.trueFalse,
    hint: 'Sezgisinle yanıtla.',
  ),
  _Question(
    text: 'Toplantı yoğunluğu makul.',
    type: _QuestionType.yesNo,
    hint: 'Evet ya da hayır seç.',
  ),
  _Question(
    text: 'İş-yaşam dengen nasıl?',
    type: _QuestionType.scale5,
    hint: '1: çok kötü · 5: harika',
  ),
  _Question(
    text: 'Yönetici desteği yeterli mi?',
    type: _QuestionType.yesNo,
    hint: 'İçgüdüyle yanıtla.',
  ),
  _Question(
    text: 'Bu çeyreğin genel ruh halin?',
    type: _QuestionType.emoji5,
    hint: 'Genel hissini emoji ile belirt.',
  ),
  _Question(
    text: 'Hangi çalışma modelini tercih edersin?',
    type: _QuestionType.scale10,
    hint: '0: tam uzaktan · 10: tam ofis',
  ),
];

class _SurveyMeta {
  const _SurveyMeta({
    required this.id,
    required this.title,
    required this.sender,
    required this.totalQuestions,
  });
  final String id;
  final String title;
  final String sender;
  final int totalQuestions;
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class SurveyAnswerScreen extends StatefulWidget {
  const SurveyAnswerScreen({super.key, required this.surveyId});

  final String surveyId;

  @override
  State<SurveyAnswerScreen> createState() => _SurveyAnswerScreenState();
}

class _SurveyAnswerScreenState extends State<SurveyAnswerScreen> {
  int _step = 0;
  final Map<int, dynamic> _answers = {};
  bool _submitted = false;

  _Question get _current => _kQuestions[_step % _kQuestions.length];
  int get _totalSteps => _kDemoSurvey.totalQuestions;

  void _answer(dynamic value) {
    setState(() => _answers[_step] = value);
  }

  void _next() {
    if (_step >= _totalSteps - 1) {
      setState(() => _submitted = true);
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _ThankYouScreen(onHome: () => context.go('/'));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final ink    = isDark ? AppColors.darkInk   : AppColors.lightInk;
    final ink2   = isDark ? AppColors.darkInk2  : AppColors.lightInk2;
    final ink3   = isDark ? AppColors.darkInk3  : AppColors.lightInk3;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final progress = (_step + 1) / _totalSteps;
    final q        = _current;
    final answered = _answers[_step];
    final isLast   = _step == _totalSteps - 1;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _back,
                    child: Icon(Icons.arrow_back_rounded, size: 22, color: ink2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SORU ${_step + 1} / $_totalSteps  ${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ink3,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.close_rounded, size: 20, color: ink3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_kDemoSurvey.title} · ${_kDemoSurvey.sender}',
                    style: TextStyle(fontSize: 11.5, color: ink3, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.sage,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Yanıtların anonim olarak kaydedilir',
                    style: TextStyle(fontSize: 11.5, color: ink3),
                  ),
                ],
              ),
            ),

            // ── Question ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      Text(q.hint, style: TextStyle(fontSize: 14, color: ink2, height: 1.4)),
                    ],
                    const SizedBox(height: 28),

                    // ── Answer input based on type ────────────────────────────
                    switch (q.type) {
                      _QuestionType.emoji5 => _Emoji5Input(
                          selected: answered as int?,
                          onSelect: (v) { _answer(v); _next(); },
                          isDark: isDark,
                          border: border,
                        ),
                      _QuestionType.yesNo => _YesNoInput(
                          selected: answered as bool?,
                          onSelect: (v) { _answer(v); _next(); },
                          isDark: isDark,
                          border: border,
                        ),
                      _QuestionType.trueFalse => _TrueFalseInput(
                          selected: answered as bool?,
                          onSelect: (v) { _answer(v); _next(); },
                          isDark: isDark,
                          border: border,
                        ),
                      _QuestionType.scale5 => _Scale5Input(
                          selected: answered as int?,
                          onSelect: (v) { _answer(v); _next(); },
                          isDark: isDark,
                          border: border,
                          ink: ink,
                          ink2: ink2,
                        ),
                      _QuestionType.scale10 => _Scale10Input(
                          selected: answered as int?,
                          onSelect: (v) { _answer(v); _next(); },
                          isDark: isDark,
                          border: border,
                          ink: ink,
                          ink2: ink2,
                          ink3: ink3,
                        ),
                    },
                  ],
                ),
              ),
            ),

            // ── Footer nav ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _step > 0 ? _back : null,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Geri'),
                    style: TextButton.styleFrom(
                      foregroundColor: ink2,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: answered != null ? _next : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isLast ? 'Gönder' : 'İleri →',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.blue : border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_kEmojis[i], style: const TextStyle(fontSize: 28)),
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

// ─── True/False input ─────────────────────────────────────────────────────────

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
          color: AppColors.blue,
          onTap: () => onSelect(true),
          isDark: isDark,
          border: border,
        ),
        const SizedBox(width: 12),
        _BigChoiceButton(
          label: 'Yanlış',
          isSelected: selected == false,
          color: AppColors.amber,
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
              color: isSelected ? color : (isDark ? AppColors.darkInk2 : AppColors.lightInk2),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Scale 1–5 input ──────────────────────────────────────────────────────────

class _Scale5Input extends StatelessWidget {
  const _Scale5Input({
    required this.selected,
    required this.onSelect,
    required this.isDark,
    required this.border,
    required this.ink,
    required this.ink2,
  });

  final int? selected;
  final ValueChanged<int> onSelect;
  final bool isDark;
  final Color border;
  final Color ink;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final val = i + 1;
        final isSelected = selected == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
              height: 64,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.blue.withValues(alpha: 0.12)
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.blue : border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$val',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.blue : ink,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Scale 1–10 / NPS input ───────────────────────────────────────────────────

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
            Text('0 · HİÇ', style: TextStyle(fontSize: 11, color: ink3, fontWeight: FontWeight.w600)),
            Text('10 · KESİNLİKLE', style: TextStyle(fontSize: 11, color: ink3, fontWeight: FontWeight.w600)),
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
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
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

// ─── Thank you screen ─────────────────────────────────────────────────────────

class _ThankYouScreen extends StatelessWidget {
  const _ThankYouScreen({required this.onHome});
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg  = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk   : AppColors.lightInk;
    final ink2= isDark ? AppColors.darkInk2  : AppColors.lightInk2;

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
                  decoration: BoxDecoration(
                    color: AppColors.sageWash,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.sage,
                    size: 40,
                  ),
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
                  '${_kDemoSurvey.totalQuestions} sorunun tamamını yanıtladın. Yanıtların anonim olarak kaydedildi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: ink2, height: 1.55),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu anket sonuçları minimum 15 kişi cevaplandıktan sonra görüntülenebilir.',
                          style: TextStyle(fontSize: 12.5, color: ink2, height: 1.45),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Ana Sayfa',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
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

// ─── Min-N lock screen ────────────────────────────────────────────────────────

class SurveyMinNLockScreen extends StatelessWidget {
  const SurveyMinNLockScreen({
    super.key,
    this.current = 8,
    this.minRequired = 15,
    this.surveyTitle = 'Hibrit Çalışma Modeli',
  });

  final int current;
  final int minRequired;
  final String surveyTitle;

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bg       = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface  = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final ink      = isDark ? AppColors.darkInk      : AppColors.lightInk;
    final ink2     = isDark ? AppColors.darkInk2     : AppColors.lightInk2;
    final ink3     = isDark ? AppColors.darkInk3     : AppColors.lightInk3;
    final bgAlt    = isDark ? AppColors.darkBgAlt    : AppColors.lightBgAlt;
    final border   = isDark ? AppColors.borderDark   : AppColors.borderLight;
    final amberCol = isDark ? AppColors.amberDark    : AppColors.amber;
    final amberBg  = isDark ? AppColors.amberSoftDark: AppColors.amberWash;
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
              // Lock card
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
                      decoration: BoxDecoration(color: amberBg, shape: BoxShape.circle),
                      child: Icon(Icons.lock_rounded, size: 34, color: amberCol),
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
                        valueColor: AlwaysStoppedAnimation<Color>(amberCol),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Privacy info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bgAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 18, color: AppColors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gizliliğinizi korumak için minimum $minRequired yanıt eşiği uygulanmaktadır. Eşik aşıldığında sonuçlar otomatik açılır.',
                        style: TextStyle(fontSize: 12.5, color: ink2, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hatırlatma gönderildi.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: amberCol,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text(
                    'Hatırlatma Gönder',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border),
                    foregroundColor: ink2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Geri Dön',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
