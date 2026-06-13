import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../legal/legal_provider.dart';
import '../providers/auth_provider.dart';

/// KVKK acceptance gate shown at sign-in (router redirects here until accepted).
/// The body is the **published** KVKK text from the admin portal
/// (`platform_config/legal_texts.kvkk`) — so the text the user accepts is
/// exactly the text that is live. The accepted version is recorded on the user
/// document; the router re-prompts if the admin later publishes a new version.
class KvkkScreen extends ConsumerStatefulWidget {
  const KvkkScreen({super.key});

  @override
  ConsumerState<KvkkScreen> createState() => _KvkkScreenState();
}

class _KvkkScreenState extends ConsumerState<KvkkScreen> {
  bool _isChecked = false;
  bool _isAccepting = false;

  Future<void> _acceptKvkk(String version) async {
    if (!_isChecked || _isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      await ref.read(authStateNotifierProvider.notifier).acceptKvkk(version);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final async = ref.watch(legalTextsProvider);
    final doc = async.valueOrNull?['kvkk'];
    final hasText = doc != null && !doc.isUnpublished;
    final version = (doc?.version != null && doc!.version!.isNotEmpty)
        ? doc.version!
        : AppConstants.currentKvkkVersion;
    final canAccept = _isChecked && !_isAccepting && hasText;

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
                    onTap: () => Navigator.of(context).canPop()
                        ? Navigator.of(context).pop()
                        : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border),
                      ),
                      child:
                          Icon(Icons.arrow_back_rounded, size: 18, color: ink2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aydınlatma Metni',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  if (hasText)
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
                        'v$version',
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

            // Scrollable content
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (_, __) => _MessageState(
                  icon: Icons.wifi_off_rounded,
                  message: 'Aydınlatma metni yüklenemedi. İnternet bağlantını '
                      'kontrol edip tekrar dene.',
                  ink2: ink2,
                  ink3: ink3,
                ),
                data: (_) {
                  if (!hasText) {
                    return _MessageState(
                      icon: Icons.description_outlined,
                      message: 'Aydınlatma metni henüz hazır değil. Lütfen daha '
                          'sonra tekrar dene.',
                      ink2: ink2,
                      ink3: ink3,
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Non-binding summary aid above the published text.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.blueSoftDark
                                : const Color(0xFFEBF2FB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.eco_rounded,
                                  size: 18,
                                  color: AppColors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Aşağıdaki metni okuyup onaylayarak verilerinin '
                                  'bu kapsamda işlenmesini kabul etmiş olursun.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkInk2
                                        : AppColors.lightInk2,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Published KVKK text (authoritative).
                        SelectableText(
                          doc.text,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: ink2,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Sticky bottom — checkbox + accept button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: bg,
                border: Border(top: BorderSide(color: border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checkbox row
                  GestureDetector(
                    onTap: hasText
                        ? () => setState(() => _isChecked = !_isChecked)
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color:
                                _isChecked ? AppColors.blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isChecked ? AppColors.blue : ink3,
                              width: 1.5,
                            ),
                          ),
                          child: _isChecked
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'KVKK Aydınlatma Metni\'ni okudum, anladım. Verilerimin bu metinde belirtilen kapsamda işlenmesini kabul ediyorum.',
                            style: TextStyle(
                              fontSize: 13,
                              color: ink2,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Accept button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: canAccept ? () => _acceptKvkk(version) : null,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Kabul Et ve Devam',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
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
