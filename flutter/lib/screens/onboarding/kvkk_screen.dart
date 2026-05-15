import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';

class KvkkScreen extends ConsumerStatefulWidget {
  const KvkkScreen({super.key});

  @override
  ConsumerState<KvkkScreen> createState() => _KvkkScreenState();
}

class _KvkkScreenState extends ConsumerState<KvkkScreen> {
  final _scrollCtrl = ScrollController();
  bool _hasScrolledToEnd = false;
  bool _accepted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (!_hasScrolledToEnd) {
        final pos = _scrollCtrl.position;
        if (pos.pixels >= pos.maxScrollExtent - 40) {
          setState(() => _hasScrolledToEnd = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _acceptAndContinue(String version) async {
    if (!_accepted || _saving) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'kvkk_version_accepted': version,
          'kvkk_accepted_at':      FieldValue.serverTimestamp(),
        });
      }
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final legalAsync = ref.watch(legalTextsProvider);

    return legalAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Text('Yüklenemedi', style: TextStyle(color: AppColors.textMuted)),
        ),
      ),
      data: (legal) {
        final text    = legal.kvkkText.isEmpty
            ? _placeholder
            : legal.kvkkText;
        final version = legal.kvkkVersion.isEmpty ? '1.0' : legal.kvkkVersion;

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: const Text('Kişisel Verilerin Korunması'),
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
              if (!_hasScrolledToEnd)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: AppColors.bg2,
                  child: const Center(
                    child: Text(
                      '↓ Devam etmek için tamamını okuyun',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                decoration: const BoxDecoration(
                  color: AppColors.bg2,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _hasScrolledToEnd
                          ? () => setState(() => _accepted = !_accepted)
                          : null,
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _accepted ? AppColors.accent : Colors.transparent,
                              border: Border.all(
                                color: _hasScrolledToEnd
                                    ? AppColors.accent
                                    : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _accepted
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'KVKK Aydınlatma Metni\'ni okudum ve kişisel verilerimin işlenmesine onay veriyorum.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accepted ? AppColors.accent : AppColors.bg3,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: (_accepted && !_saving)
                            ? () => _acceptAndContinue(version)
                            : null,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Onayla ve Devam Et',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _placeholder = '''
Bu platform, anonim ve toplulaştırılmış çalışan deneyimi verisi sunan bir
workforce analytics hizmetidir.

Kişisel Verileriniz

Platforma LinkedIn OAuth ile giriş yaptığınızda yalnızca çalıştığınız
şirket, rolünüz ve şirket büyüklüğü bilgisi doğrulama amacıyla kullanılır.
LinkedIn kimlik numaranız sunucu tarafında geri dönüşümsüz (HMAC-SHA256 + salt)
şekilde hashlenerek saklanır; düz metin hiçbir zaman tutulmaz.

Veri Minimizasyonu

İsim, fotoğraf, bağlantı listesi, mesaj geçmişi, lokasyon veya eğitim bilgisi
gibi veriler talep edilmez ve saklanmaz.

Anonimleştirme

Check-in verileriniz bireysel olarak hiçbir zaman erişilemez. Yalnızca
belirli bir eşiği (N ≥ 15 kişi) aşan toplu istatistikler yayınlanır.

Haklarınız

KVKK kapsamında verilerinize erişim, düzeltme veya silinmesini talep
edebilirsiniz. Hesap silme işlemi uygulama içi Ayarlar menüsünden
gerçekleştirilebilir.

İletişim: legal@pom.app
''';
