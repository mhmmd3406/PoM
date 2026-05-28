import 'package:flutter/material.dart';

class CheckinStepData {
  const CheckinStepData({
    required this.title,
    required this.subtitle,
    required this.emojis,
    required this.labels,
  });

  final String title;
  final String subtitle;
  final List<String> emojis;
  final List<String> labels;

  static const List<CheckinStepData> steps = [
    CheckinStepData(
      title: 'Genel Ruh Halin',
      subtitle: 'Bu hafta kendini nasıl hissediyorsun?',
      emojis: ['😞', '😕', '😐', '🙂', '😄'],
      labels: ['Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Harika'],
    ),
    CheckinStepData(
      title: 'İş Stresi',
      subtitle: 'İşindeki stres seviyeni nasıl değerlendirirsin?',
      emojis: ['😰', '😟', '😐', '😌', '😎'],
      labels: ['Çok Stresli', 'Stresli', 'Orta', 'Rahat', 'Çok Rahat'],
    ),
    CheckinStepData(
      title: 'Takım Uyumu',
      subtitle: 'Ekibinle ilişkilerin nasıl?',
      emojis: ['😠', '😕', '😐', '😊', '🤗'],
      labels: ['Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Mükemmel'],
    ),
    CheckinStepData(
      title: 'Kişisel Gelişim',
      subtitle: 'İşinde kendini ne kadar geliştirdiğini hissediyorsun?',
      emojis: ['📉', '😕', '😐', '📈', '🚀'],
      labels: ['Geriliyorum', 'Az', 'Orta', 'İyi', 'Mükemmel'],
    ),
    CheckinStepData(
      title: 'İş-Yaşam Dengesi',
      subtitle: 'İş ve özel hayatın arasındaki denge nasıl?',
      emojis: ['⚡', '😓', '😐', '🌿', '🌟'],
      labels: ['Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Mükemmel'],
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
  final Future<void> Function(int) onSelect;

  @override
  State<CheckinStepWidget> createState() => _CheckinStepWidgetState();
}

class _CheckinStepWidgetState extends State<CheckinStepWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
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

    return ScaleTransition(
      scale: _scaleAnim,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.stepData.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            widget.stepData.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          // Emoji row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final value = index + 1; // 1–5
              final isSelected = widget.selectedValue == value;
              return _EmojiButton(
                emoji: widget.stepData.emojis[index],
                label: widget.stepData.labels[index],
                isSelected: isSelected,
                onTap: () => widget.onSelect(value),
              );
            }),
          ),
          const SizedBox(height: 32),
          if (widget.selectedValue != null)
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.stepData.labels[widget.selectedValue! - 1],
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool isSelected;
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
      duration: const Duration(milliseconds: 200),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1), weight: 50),
    ]).animate(_bounceController);
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
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isSelected ? _bounceAnim.value : 1.0,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: widget.isSelected
                ? Border.all(color: scheme.primary, width: 2.5)
                : null,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.emoji,
              style: TextStyle(
                fontSize: widget.isSelected ? 30 : 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
