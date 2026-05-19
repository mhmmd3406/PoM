import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startLinkedInOAuth() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.launchLinkedInOAuth();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('LinkedIn bağlantısı açılamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(authStateNotifierProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final bool isWorking = _isLoading || authState.isLoading;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // PoM logo mark in header (left-aligned)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                  ),

                  const SizedBox(height: 28),

                  // Illustration card
                  Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2010)
                          : const Color(0xFFF8F0E0),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CustomPaint(
                        painter: _MeditationPainter(isDark: isDark),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // HOŞ GELDİN label
                  Text(
                    'HOŞ GELDİN',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // "Tekrar görüşmek güzel." — "güzel." in italic blue
                  RichText(
                    textAlign: TextAlign.left,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tekrar görüşmek\n',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: ink,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                        TextSpan(
                          text: 'güzel.',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: AppColors.blue,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'İş e-postanla ilişkili LinkedIn hesabınla giriş yap. Anonimliğin korunur.',
                      style: TextStyle(
                        fontSize: 14,
                        color: ink2,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // LinkedIn primary button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isWorking ? null : _startLinkedInOAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.linkedIn,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isWorking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LinkedInIcon(),
                                const SizedBox(width: 10),
                                Text(
                                  'LinkedIn ile giriş yap',
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
                  const SizedBox(height: 12),

                  // Support button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: BorderSide(color: border.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Sorun mu yaşıyorsun? Destek',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ink2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Meditation figure illustration ───────────────────────────────────────────

class _MeditationPainter extends CustomPainter {
  const _MeditationPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Meditation cushion/shadow (brown ellipse)
    paint.color = isDark ? const Color(0xFF8A5A30) : const Color(0xFFB87840);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.82),
        width: w * 0.35,
        height: h * 0.10,
      ),
      paint,
    );

    // Body (blue rounded rect, slightly wider at bottom)
    paint.color = isDark ? const Color(0xFF5570A0) : const Color(0xFF5B82C0);
    final bodyPath = Path()
      ..moveTo(w * 0.34, h * 0.78)
      ..quadraticBezierTo(w * 0.30, h * 0.55, w * 0.36, h * 0.44)
      ..quadraticBezierTo(w * 0.50, h * 0.40, w * 0.64, h * 0.44)
      ..quadraticBezierTo(w * 0.70, h * 0.55, w * 0.66, h * 0.78)
      ..close();
    canvas.drawPath(bodyPath, paint);

    // Head skin
    paint.color = isDark ? const Color(0xFFB89060) : const Color(0xFFD4A870);
    canvas.drawCircle(Offset(w * 0.50, h * 0.34), w * 0.105, paint);

    // Eyes closed (two small arcs)
    final eyePaint = Paint()
      ..color = isDark ? const Color(0xFF6A4020) : const Color(0xFF4A2810)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.455, h * 0.335), width: 10, height: 6),
      pi,
      pi,
      false,
      eyePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.545, h * 0.335), width: 10, height: 6),
      pi,
      pi,
      false,
      eyePaint,
    );

    // Decorative dots around figure
    final dotPositions = [
      (w * 0.22, h * 0.28, const Color(0xFFE8A53C)),
      (w * 0.78, h * 0.24, const Color(0xFF72B8C8)),
      (w * 0.18, h * 0.55, const Color(0xFF72C892)),
      (w * 0.82, h * 0.50, const Color(0xFF72B8C8)),
    ];
    for (final (dx, dy, dotColor) in dotPositions) {
      paint.color = dotColor.withValues(alpha: isDark ? 0.7 : 0.9);
      canvas.drawCircle(Offset(dx, dy), 4, paint);
    }
  }

  @override
  bool shouldRepaint(_MeditationPainter old) => old.isDark != isDark;
}

// ─── Shared logo mark ────────────────────────────────────────────────────────

class _PomLogoMark extends StatelessWidget {
  const _PomLogoMark({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
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
