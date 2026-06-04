import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

final onboardingDoneProvider = StateProvider<bool>((ref) => false);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ref.read(onboardingDoneProvider.notifier).state = true;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: PoM logo + Atla
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
              child: Row(
                children: [
                  Row(
                    children: [
                      _PomLogoMark(isDark: isDark),
                      const SizedBox(width: 8),
                      Text(
                        'PoM',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Atla',
                      style: TextStyle(color: ink3, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: 3,
                itemBuilder: (context, i) => _OnboardingPageContent(
                  pageIndex: i,
                  isDark: isDark,
                  ink: ink,
                  ink3: ink3,
                ),
              ),
            ),

            // Dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  // Indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.blue
                              : (isDark
                                  ? AppColors.darkInk3
                                  : const Color(0xFFCDC8C1)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary CTA
                  if (_currentPage == 2) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _finish,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.linkedIn,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LinkedInIcon(),
                            const SizedBox(width: 8),
                            Text(
                              'LinkedIn ile devam et',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style:
                            TextStyle(fontSize: 12, color: ink3, height: 1.4),
                        children: [
                          const TextSpan(text: 'Devam ederek '),
                          TextSpan(
                            text: 'Kullanım Koşulları',
                            style: const TextStyle(
                                color: AppColors.blue,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.blue),
                          ),
                          const TextSpan(text: ' ve '),
                          TextSpan(
                            text: 'KVKK Aydınlatma',
                            style: const TextStyle(
                                color: AppColors.blue,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.blue),
                          ),
                          const TextSpan(text: ' metnini kabul edersin.'),
                        ],
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.lightBg
                              : const Color(0xFF1B2230),
                          foregroundColor:
                              isDark ? AppColors.lightInk : AppColors.lightBg,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Devam',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.lightInk
                                    : AppColors.lightBg,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.lightInk
                                  : AppColors.lightBg,
                            ),
                          ],
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

// ─── Page content ─────────────────────────────────────────────────────────────

class _OnboardingPageContent extends StatelessWidget {
  const _OnboardingPageContent({
    required this.pageIndex,
    required this.isDark,
    required this.ink,
    required this.ink3,
  });

  final int pageIndex;
  final bool isDark;
  final Color ink;
  final Color ink3;

  static const _labels = [
    'POM · PEACE OF MİND',
    'ANONİM VE GÜVENLİ',
    'SEKTÖRÜNLE KARŞILAŞTIR',
  ];

  static const _titles = [
    'Haftalık 5 soru,\nbir adım daha sakin.',
    'Verin sana ait.\nŞirket sadece\ntoplamı görür.',
    'Kendini ve şirketini\nbağlamla anla.',
  ];

  static const _subtitles = [
    'Her hafta sadece 60 saniyenle ruh halini, iş stresini ve takım uyumunu ölç. Zamanla nereye gidiyorsun görürsün.',
    'Bireysel cevapların kimseyle paylaşılmaz. Şirket yöneticileri sadece anonim ortalama ve toplulukları görür. Minimum N eşiği uygulanır.',
    'Kişisel skorunu şirket ortalamasıyla, şirketini sektör ortalamasıyla karşılaştır. Refahı bir veri kaynağı olarak kullan.',
  ];

  Color _cardBg() {
    if (pageIndex == 2) {
      return isDark ? const Color(0xFF1A2E28) : const Color(0xFFD8EEE6);
    }
    return isDark ? AppColors.blueSoftDark : AppColors.blueSoft;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration card
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                height: 230,
                decoration: BoxDecoration(
                  color: _cardBg(),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(
                    painter: _IllustrationPainter(
                        pageIndex: pageIndex, isDark: isDark),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              // "60 saniye" badge on page 1
              if (pageIndex == 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.sage,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '60 saniye',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkInk
                                : AppColors.lightInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Blue category label
          Text(
            _labels[pageIndex],
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            _titles[pageIndex],
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: ink,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            _subtitles[pageIndex],
            style: TextStyle(fontSize: 14, color: ink3, height: 1.55),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Illustration Painter ─────────────────────────────────────────────────────

class _IllustrationPainter extends CustomPainter {
  const _IllustrationPainter({required this.pageIndex, required this.isDark});
  final int pageIndex;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    switch (pageIndex) {
      case 0:
        _paintPlant(canvas, size);
      case 1:
        _paintPeople(canvas, size);
      case 2:
        _paintLandscape(canvas, size);
    }
  }

  void _paintPlant(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Pot body
    paint.color = const Color(0xFFC27A50);
    final potPath = Path()
      ..moveTo(w * 0.40, h * 0.62)
      ..lineTo(w * 0.33, h * 0.86)
      ..quadraticBezierTo(w * 0.50, h * 0.90, w * 0.67, h * 0.86)
      ..lineTo(w * 0.60, h * 0.62)
      ..close();
    canvas.drawPath(potPath, paint);

    // Pot rim
    paint.color = const Color(0xFFAD6C42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.63),
            width: w * 0.40,
            height: h * 0.065),
        const Radius.circular(6),
      ),
      paint,
    );

    // Left leaf
    paint.color = const Color(0xFF4E9058);
    final leftLeaf = Path()
      ..moveTo(w * 0.47, h * 0.60)
      ..cubicTo(w * 0.22, h * 0.46, w * 0.16, h * 0.20, w * 0.30, h * 0.12)
      ..cubicTo(w * 0.44, h * 0.20, w * 0.47, h * 0.44, w * 0.47, h * 0.60);
    canvas.drawPath(leftLeaf, paint);

    // Center leaf
    paint.color = const Color(0xFF5DAD6C);
    final centerLeaf = Path()
      ..moveTo(w * 0.50, h * 0.60)
      ..cubicTo(w * 0.38, h * 0.38, w * 0.44, h * 0.10, w * 0.50, h * 0.06)
      ..cubicTo(w * 0.56, h * 0.10, w * 0.62, h * 0.38, w * 0.50, h * 0.60);
    canvas.drawPath(centerLeaf, paint);

    // Right leaf
    paint.color = const Color(0xFF4E9058);
    final rightLeaf = Path()
      ..moveTo(w * 0.53, h * 0.58)
      ..cubicTo(w * 0.78, h * 0.42, w * 0.86, h * 0.16, w * 0.72, h * 0.08)
      ..cubicTo(w * 0.58, h * 0.16, w * 0.53, h * 0.40, w * 0.53, h * 0.58);
    canvas.drawPath(rightLeaf, paint);
  }

  void _paintPeople(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    final figures = [
      (w * 0.25, const Color(0xFF5DA86E), const Color(0xFFD4B896)),
      (w * 0.50, const Color(0xFF5B88C4), const Color(0xFFB8936A)),
      (w * 0.75, const Color(0xFFE8A53C), const Color(0xFFD4B896)),
    ];

    for (final (cx, bodyColor, skinColor) in figures) {
      final baseY = h * 0.75;

      // Body
      paint.color = bodyColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, baseY - h * 0.06),
              width: w * 0.14,
              height: h * 0.32),
          const Radius.circular(30),
        ),
        paint,
      );

      // Head
      paint.color = skinColor;
      canvas.drawCircle(Offset(cx, baseY - h * 0.30), w * 0.075, paint);
    }

    // Hearts
    paint.color = const Color(0xFFE86A6A);
    _drawHeart(canvas, paint, w * 0.20, h * 0.24, 9);
    paint.color = const Color(0xFFE8A53C);
    _drawHeart(canvas, paint, w * 0.72, h * 0.18, 8);
  }

  void _drawHeart(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path()
      ..moveTo(cx, cy + r * 0.9)
      ..cubicTo(cx - r * 1.5, cy + r * 0.2, cx - r * 1.5, cy - r * 0.7,
          cx, cy - r * 0.1)
      ..cubicTo(cx + r * 1.5, cy - r * 0.7, cx + r * 1.5, cy + r * 0.2,
          cx, cy + r * 0.9);
    canvas.drawPath(path, paint);
  }

  void _paintLandscape(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Sky
    paint.color = isDark ? const Color(0xFF1A2C26) : const Color(0xFFC8E8DE);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.72), paint);

    // Cloud
    paint.color = isDark ? const Color(0xFF2A3F38) : const Color(0xFFE8F4F0);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.28, h * 0.28), width: w * 0.30, height: h * 0.10),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.19, h * 0.32), width: w * 0.18, height: h * 0.08),
        paint);

    // Sun
    paint.color = const Color(0xFFE8A53C);
    canvas.drawCircle(Offset(w * 0.58, h * 0.38), w * 0.13, paint);

    // Back hill
    paint.color = isDark ? const Color(0xFF2A4A3A) : const Color(0xFF7DBF8A);
    final backHill = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.35, h * 0.46, w * 0.75, h * 0.70)
      ..lineTo(w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(backHill, paint);

    // Front hill
    paint.color = isDark ? const Color(0xFF3A6A50) : const Color(0xFF5AAA69);
    final frontHill = Path()
      ..moveTo(0, h * 0.82)
      ..quadraticBezierTo(w * 0.28, h * 0.62, w * 0.58, h * 0.80)
      ..quadraticBezierTo(w * 0.78, h * 0.92, w, h * 0.76)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(frontHill, paint);

    // Tree trunk
    paint.color = isDark ? const Color(0xFF5A4030) : const Color(0xFF7A5538);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w * 0.76, h * 0.79),
            width: w * 0.025,
            height: h * 0.10),
        paint);

    // Tree crown
    paint.color = isDark ? const Color(0xFF2A4A3A) : const Color(0xFF4A8A58);
    canvas.drawCircle(Offset(w * 0.76, h * 0.70), w * 0.065, paint);
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.pageIndex != pageIndex || old.isDark != isDark;
}

// ─── PoM logo mark ────────────────────────────────────────────────────────────

class _PomLogoMark extends StatelessWidget {
  const _PomLogoMark({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.sage,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LinkedIn icon ────────────────────────────────────────────────────────────

class _LinkedInIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'in',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.linkedIn,
            height: 1,
          ),
        ),
      ),
    );
  }
}
