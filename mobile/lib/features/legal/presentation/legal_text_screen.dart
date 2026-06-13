import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../legal_provider.dart';

/// Read-only viewer for a single legal document published from the admin portal
/// (`platform_config/legal_texts`). Reached from Profile → Yasal Metinler via
/// `/legal/:key`. Renders the admin-authored plain text, with the live version
/// and last-updated date shown in the header.
class LegalTextScreen extends ConsumerWidget {
  const LegalTextScreen({super.key, required this.docKey});

  final String docKey;

  static String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final meta = legalMetaForKey(docKey);
    final title = meta?.label ?? 'Yasal Metin';
    final async = ref.watch(legalTextsProvider);
    final doc = async.valueOrNull?[docKey];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border),
                      ),
                      child: Icon(Icons.arrow_back_rounded, size: 18, color: ink2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  if (doc?.version != null && doc!.version!.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceSoft
                            : AppColors.lightBgAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v${doc.version}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ink3,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (_, __) => _MessageState(
                  icon: Icons.wifi_off_rounded,
                  message: 'Metin yüklenemedi. İnternet bağlantını kontrol edip '
                      'tekrar dene.',
                  ink2: ink2,
                  ink3: ink3,
                ),
                data: (_) {
                  if (doc == null || doc.isUnpublished) {
                    return _MessageState(
                      icon: Icons.description_outlined,
                      message: 'Bu metin henüz yayınlanmadı.',
                      ink2: ink2,
                      ink3: ink3,
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          doc.text,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: ink2,
                            height: 1.6,
                          ),
                        ),
                        if (doc.updatedAt != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Son güncelleme: ${_formatDate(doc.updatedAt!)}',
                            style: TextStyle(fontSize: 12, color: ink3),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.ink2,
    required this.ink3,
  });

  final IconData icon;
  final String message;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: ink3),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
