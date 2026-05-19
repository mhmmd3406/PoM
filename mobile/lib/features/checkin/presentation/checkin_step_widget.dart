import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CheckinStepData {
  const CheckinStepData({
    required this.title,
    required this.subtitle,
    required this.emojis,
    required this.labels,
    required this.dimensionEmoji,
    required this.dimensionLabel,
    required this.chipColor,
    required this.chipBg,
  });

  final String title;
  final String subtitle;
  final List<String> emojis;
  final List<String> labels;
  final String dimensionEmoji;
  final String dimensionLabel;
  final Color chipColor;
  final Color chipBg;

  static const List<CheckinStepData> steps = [
    CheckinStepData(
      title: 'Genel Ruh Halin',
      subtitle: 'Bu hafta kendini nasıl hissediyorsun?',
      emojis: ['😞', '😕', '😐', '🙂', '😄'],
      labels: ['Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Harika'],
      dimensionEmoji: '😊',
      dimensionLabel: 'Ruh Hali',
      chipColor: AppColors.blue,
      chipBg: AppColors.blueSoft,
    ),
    CheckinStepData(
      title: 'İş Stresi',
      subtitle: 'İşindeki stres seviyeni nasıl değerlendirirsin?',
      emojis: ['😰', '😟', '😐', '😌', '😎'],
      labels: ['Çok Stresli', 'Stresli', 'Orta', 'Rahat', 'Çok Rahat'],
      dimensionEmoji: '😌',
      dimensionLabel: 'Stres',
      chipColor: AppColors.amber,
      chipBg: AppColors.amberSoft,
    ),
    CheckinStepData(
      title: 'Takım Uyumu',
      subtitle: 'Ekibinle ilişkilerin nasıl?',
      emojis: ['😠', '😕', '😐', '😊', '🤗'],
      labels: ['Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Mükemmel'],
      dimensionEmoji: '🤝',
      dimensionLabel: 'Takım',
      chipColor: AppColors.sage,
      chipBg: AppColors.sageSoft,
    ),
    CheckinStepData(
      title: 'Kişisel Gelişim',
      subtitle: 'İşinde kendini ne kadar geliştirdiğini hissediyorsun?',
      emojis: ['📉', '😕', '😐', '📈', '🚀'],
      labels: ['Geriliyorum', 'Az', 'Orta', 'İyi', 'Mükemmel'],
      dimensionEmoji: '🌱',
      dimensionLabel: 'Gelişim',
      chipColor: AppColors.moss,
      chipBg: AppColors.sageSoft,
    ),
    CheckinStepData(
      title: 'İş-Yaşam Dengesi',
      subtitle: 'İş ve özel hayatın arasındaki denge nasıl?',
      emojis: ['⚡', '😓', '😐', '🌿', '🌟'],
      labels: ['Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Mükemmel'],
      dimensionEmoji: '⚖️',
      dimensionLabel: 'Denge',
      chipColor: AppColors.blue,
      chipBg: AppColors.blueWash,
    ),
  ];
}

class CheckinStepWidget extends StatefulWidget {
  const CheckinStepWidget({
    super.key,
    required this.stepData,
    required this.selectedValue,
    required this.onSelect,
  });

  final CheckinStepData stepData;
  final int? selectedValue; // 1–5, null if unselected
  final ValueChanged<int> onSelect;

  @override
  State<CheckinStepWidget> createState() => _CheckinStepWidgetState();
}

class _CheckinStepWidgetState extends State<CheckinStepWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step = widget.stepData;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dimension chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: step.chipBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step.dimensionEmoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  step.dimensionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: step.chipColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            step.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          // Emoji row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final value = index + 1;
              final isSelected = widget.selectedValue == value;
              return _EmojiButton(
                emoji: step.emojis[index],
                label: step.labels[index],
                isSelected: isSelected,
                chipColor: step.chipColor,
                onTap: () => widget.onSelect(value),
              );
            }),
          ),
          const SizedBox(height: 28),
          // Selected label pill
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.selectedValue != null
                ? Container(
                    key: ValueKey(widget.selectedValue),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: step.chipColor,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: step.chipColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      step.labels[widget.selectedValue! - 1],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  )
                : const SizedBox(height: 40),
          ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  const _EmojiButton({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.chipColor,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool isSelected;
  final Color chipColor;
  final VoidCallback onTap;

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1), weight: 60),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_EmojiButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (context, child) => Transform.scale(
          scale: widget.isSelected ? _bounceAnim.value : 1.0,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.chipColor.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: widget.isSelected
                ? Border.all(color: widget.chipColor, width: 2)
                : Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    width: 1,
                  ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.chipColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.emoji,
              style: TextStyle(fontSize: widget.isSelected ? 30 : 26),
            ),
          ),
        ),
      ),
    );
  }
}
