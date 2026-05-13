import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class EmojiRatingPicker extends StatelessWidget {
  const EmojiRatingPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accentColor,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final Color accentColor;

  static const _emojis = ['😫', '😕', '😐', '😊', '🤩'];
  static const _labels = ['Struggling', 'Below Average', "It's OK", 'Pretty Good', 'Excellent!'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Large animated preview
        SizedBox(
          height: 100,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: value != null
                ? Text(_emojis[value! - 1],
                    key: ValueKey(value),
                    style: const TextStyle(fontSize: 84))
                : Text('· · ·',
                    key: const Key('none'),
                    style: TextStyle(
                        fontSize: 22,
                        color: Colors.white.withOpacity(0.2),
                        letterSpacing: 6)),
          ),
        ),

        const SizedBox(height: 8),

        // Animated label
        SizedBox(
          height: 24,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              value != null ? _labels[value! - 1] : 'Tap to rate',
              key: ValueKey('lbl_$value'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: value != null ? accentColor : Colors.white30,
              ),
            ),
          ),
        ),

        const SizedBox(height: 40),

        // 5 emoji buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            final rating = i + 1;
            final selected = value == rating;
            return _EmojiButton(
              emoji: _emojis[i],
              selected: selected,
              color: AppColors.ratingColors[i],
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(rating);
              },
            );
          }),
        ),
      ],
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.45 : 1.0,
          duration: const Duration(milliseconds: 480),
          curve: Curves.elasticOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.22) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color.withOpacity(0.75) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 32)),
          ),
        ),
      );
}
