import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class KvkkScreen extends ConsumerStatefulWidget {
  const KvkkScreen({super.key});

  @override
  ConsumerState<KvkkScreen> createState() => _KvkkScreenState();
}

class _KvkkScreenState extends ConsumerState<KvkkScreen> {
  bool _isChecked = false;
  bool _isAccepting = false;

  Future<void> _acceptKvkk() async {
    if (!_isChecked || _isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      await ref.read(authStateNotifierProvider.notifier).acceptKvkk();
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
                    onTap: () =>
                        Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
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
                      'Aydınlatma Metni',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSoft : AppColors.lightBgAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'v1.0',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary card
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
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkInk2 : AppColors.lightInk2,
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Kısa özet: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: 'Verin anonim olarak saklanır. Şirket yöneticisi sadece ',
                                  ),
                                  TextSpan(
                                    text: '15+ kişilik toplu',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' sonuçları görür. Veriler Türkiye\'deki sunucularda tutulur.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      context,
                      '1. Veri Sorumlusu',
                      'PoM Teknoloji A.Ş., 6698 sayılı KVKK kapsamında veri sorumlusudur. İletişim: kvkk@pom.app',
                      ink: ink,
                      ink2: ink2,
                    ),
                    _buildSection(
                      context,
                      '2. İşlenen Veriler',
                      'LinkedIn profilinden alınan ad-soyad, e-posta, şirket bilgisi; haftalık check-in cevapların (1–5 ölçek); cihaz/oturum bilgisi.',
                      ink: ink,
                      ink2: ink2,
                    ),
                    _buildSection(
                      context,
                      '3. İşleme Amaçları',
                      'Hizmet sunmak, kişisel içgörü üretmek, anonim toplu analiz sağlamak. Bireysel cevapların pazarlama için kullanılmaz.',
                      ink: ink,
                      ink2: ink2,
                    ),
                    _buildSection(
                      context,
                      '4. Anonimleştirme',
                      'Şirket panelinde minimum N=15 eşiği altında veri gösterilmez. Departman seviyesinde N=10. Tek tek cevapların hiçbir yönetici tarafından görülemez.',
                      ink: ink,
                      ink2: ink2,
                    ),
                    _buildSection(
                      context,
                      '5. Haklarınız',
                      'KVKK md.11 uyarınca verilerine erişme, düzeltme, silme, işlemeye itiraz etme hakların var. Talep için kvkk@pom.app.',
                      ink: ink,
                      ink2: ink2,
                    ),
                  ],
                ),
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
                    onTap: () => setState(() => _isChecked = !_isChecked),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _isChecked ? AppColors.blue : Colors.transparent,
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
                      onPressed: (_isChecked && !_isAccepting) ? _acceptKvkk : null,
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

  Widget _buildSection(
    BuildContext context,
    String title,
    String body, {
    required Color ink,
    required Color ink2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: ink2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
