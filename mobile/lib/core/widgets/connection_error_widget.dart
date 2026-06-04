import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Full-screen connection / offline error state.
/// Drop it into any `when(error: ...)` or show it via a conditional in build.
class ConnectionErrorWidget extends StatelessWidget {
  const ConnectionErrorWidget({
    super.key,
    this.onRetry,
    this.title = 'Bağlantı kurulamadı',
    this.message = 'İnternet bağlantını kontrol et ve tekrar dene.',
  });

  final VoidCallback? onRetry;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.darkBg     : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk     : AppColors.lightInk;
    final ink2    = isDark ? AppColors.darkInk2    : AppColors.lightInk2;
    final border  = isDark ? AppColors.borderDark  : AppColors.borderLight;
    final roseBg  = isDark ? const Color(0xFF3D1E1E) : const Color(0xFFFCECEA);
    final rose    = isDark ? AppColors.rose    : AppColors.rose;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: roseBg, shape: BoxShape.circle),
                  child: Icon(Icons.wifi_off_rounded, size: 36, color: rose),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Message
                Text(
                  message,
                  style: TextStyle(fontSize: 14, color: ink2, height: 1.55),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Tips card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Şunları dene:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final tip in const [
                        'Wi-Fi veya mobil verini kontrol et',
                        'Uçak modunu kapatıp aç',
                        'Uygulamayı yeniden başlat',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 5, color: AppColors.blue),
                              const SizedBox(width: 8),
                              Text(
                                tip,
                                style: TextStyle(fontSize: 13, color: ink2),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Retry button
                if (onRetry != null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Tekrar Dene',
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

/// Inline version — use inside any widget tree (not full-screen).
class ConnectionErrorInline extends StatelessWidget {
  const ConnectionErrorInline({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink2   = isDark ? AppColors.darkInk2 : AppColors.lightInk2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40,
                color: isDark ? AppColors.rose : AppColors.rose),
            const SizedBox(height: 12),
            Text(
              'Bağlantı kurulamadı',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.lightInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'İnternet bağlantını kontrol et.',
              style: TextStyle(fontSize: 13, color: ink2),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
