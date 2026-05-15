import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class KvkkScreen extends ConsumerStatefulWidget {
  const KvkkScreen({super.key});

  @override
  ConsumerState<KvkkScreen> createState() => _KvkkScreenState();
}

class _KvkkScreenState extends ConsumerState<KvkkScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToEnd = false;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    // Allow small margin for rounding errors
    if (!_scrolledToEnd && current >= maxScroll - 32) {
      setState(() => _scrolledToEnd = true);
    }
  }

  Future<void> _acceptKvkk() async {
    if (!_scrolledToEnd || _isAccepting) return;
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KVKK Aydınlatma Metni'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Progress hint banner
          Container(
            width: double.infinity,
            color: scheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _scrolledToEnd
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: _scrolledToEnd
                      ? scheme.secondary
                      : scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _scrolledToEnd
                        ? 'Metni okudunuz. Onaylamak için aşağıdaki butona basın.'
                        : 'Lütfen onaylamak için metnin tamamını okuyun.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable KVKK text
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: const _KvkkContent(),
            ),
          ),

          // Accept button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              children: [
                if (!_scrolledToEnd)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Kabul etmek için lütfen metni sonuna kadar okuyun.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _scrolledToEnd && !_isAccepting
                        ? _acceptKvkk
                        : null,
                    child: _isAccepting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Kabul Et'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KVKK Content Widget ──────────────────────────────────────────────────────

class _KvkkContent extends StatelessWidget {
  const _KvkkContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KİŞİSEL VERİLERİN KORUNMASI VE GİZLİLİK POLİTİKASI',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Versiyon 1.0 — Son güncelleme: Mayıs 2026',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildSection(
          context,
          '1. VERİ SORUMLUSU',
          '6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, kişisel verileriniz; '
              'veri sorumlusu sıfatıyla Peace of Mind Teknoloji A.Ş. ("PoM" veya "Şirket") tarafından '
              'aşağıda açıklanan kapsamda işlenecektir. PoM, KVKK\'nın 10. maddesi çerçevesinde '
              'sizi bu hususta bilgilendirmekle yükümlüdür.',
        ),
        _buildSection(
          context,
          '2. İŞLENEN KİŞİSEL VERİLER VE İŞLEME AMAÇLARI',
          'PoM uygulaması aracılığıyla aşağıdaki kişisel verileriniz işlenmektedir:\n\n'
              '• Kimlik verisi: LinkedIn üzerinden alınan ad-soyad (isteğe bağlı) ve benzersiz LinkedIn kimliği '
              '(HMAC-SHA256 ile anonim hale getirilmiş hash değeri).\n\n'
              '• İletişim verisi: LinkedIn üzerinden alınan e-posta adresi (yalnızca hesap yönetimi amacıyla).\n\n'
              '• Uygulama kullanım verisi: Haftalık ruh hali anketi sonuçları (genel ruh hali, iş stresi, '
              'takım uyumu, kişisel gelişim, iş-yaşam dengesi boyutlarında 1-5 arası puan).\n\n'
              '• Ödeme verisi: Stripe ödeme işlemcisi aracılığıyla gerçekleştirilen abonelik ve kredi '
              'satın alma işlemlerine ilişkin işlem kimliği ve tutar bilgileri. Kart numarası, CVV gibi '
              'hassas veriler PoM sistemlerinde tutulmaz; doğrudan Stripe\'a iletilir.\n\n'
              '• Teknik veri: Cihaz bilgisi, IP adresi, uygulama oturum verileri.\n\n'
              'Söz konusu veriler; hizmetin sunulması, kullanıcı güvenliğinin sağlanması, yasal '
              'yükümlülüklerin yerine getirilmesi ve kullanıcı deneyiminin iyileştirilmesi amaçlarıyla işlenmektedir.',
        ),
        _buildSection(
          context,
          '3. ANONİMLEŞTİRME VE TOPLU VERİ ANALİZİ',
          'LinkedIn kimliğiniz, sistemlerimizde kriptografik hash (HMAC-SHA256) fonksiyonu kullanılarak '
              'anonim hale getirilmektedir. LinkedIn kimliğiniz kesinlikle ham biçimde saklanmamaktadır.\n\n'
              'Anket sonuçları; şirket, departman ve sektör bazında istatistiki içgörüler oluşturmak '
              'amacıyla toplu olarak analiz edilmektedir. Şirket veya departman bazındaki toplu veriler '
              'yalnızca asgari katılımcı eşiği (şirket düzeyi için en az 15, departman düzeyi için en az 10) '
              'sağlandığında paylaşılmakta; bu sayede bireysel veriler korunmaktadır.',
        ),
        _buildSection(
          context,
          '4. VERİ İŞLEMENİN HUKUKİ DAYANAĞI',
          'Kişisel verileriniz;\n\n'
              '• KVKK md. 5/2-(a): Sözleşmenin kurulması veya ifası için zorunlu olması,\n'
              '• KVKK md. 5/2-(ç): Veri sorumlusunun hukuki yükümlülüğünü yerine getirmesi,\n'
              '• KVKK md. 5/1: Açık rızanız (pazarlama ve profil analizi gibi zorunlu olmayan işlemler için)\n\n'
              'hukuki dayanakları çerçevesinde işlenmektedir.',
        ),
        _buildSection(
          context,
          '5. VERİLERİN AKTARILMASI',
          'Kişisel verileriniz;\n\n'
              '• Stripe Inc. — ödeme işlemleri için (PCI-DSS uyumlu, ABD merkezli),\n'
              '• Google LLC (Firebase / Google Cloud) — veri depolama ve kimlik doğrulama için,\n'
              '• Mevzuatın öngördüğü durumlarda yetkili kamu kurum ve kuruluşlarına\n\n'
              'aktarılabilecektir. Üçüncü taraf hizmet sağlayıcılar, verilerinizi yalnızca PoM adına '
              'hizmet sunmak amacıyla işlemekte ve verilerinizi kendi amaçları için kullanamamaktadır.',
        ),
        _buildSection(
          context,
          '6. VERİ SAKLAMA SÜRESİ',
          'Hesabınız aktif olduğu sürece verileriniz saklanır. Hesabınızı silmeniz durumunda;\n\n'
              '• Kimlik ve anket verileri 90 gün içinde silinir.\n'
              '• Ödeme kayıtları yasal yükümlülükler gereği 10 yıl süreyle saklanır.\n'
              '• Toplu/anonim istatistiksel veriler süresiz olarak saklanabilir.',
        ),
        _buildSection(
          context,
          '7. İLGİLİ KİŞİ OLARAK HAKLARINIZ',
          'KVKK\'nın 11. maddesi uyarınca aşağıdaki haklara sahipsiniz:\n\n'
              '• Kişisel verilerinizin işlenip işlenmediğini öğrenme,\n'
              '• İşleniyorsa buna ilişkin bilgi talep etme,\n'
              '• İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,\n'
              '• Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,\n'
              '• Eksik veya yanlış işlenmesi hâlinde düzeltilmesini isteme,\n'
              '• KVKK md. 7 çerçevesinde silinmesini veya yok edilmesini isteme,\n'
              '• Düzeltme ve silme işlemlerinin aktarılan üçüncü kişilere bildirilmesini isteme,\n'
              '• İşlenen verilerin münhasıran otomatik sistemler vasıtasıyla analiz edilmesi '
              'suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme,\n'
              '• Kanuna aykırı işlenmesi nedeniyle zarara uğramanız hâlinde zararın giderilmesini talep etme.\n\n'
              'Bu haklarınızı kullanmak için kvkk@pom.app adresine e-posta gönderebilirsiniz.',
        ),
        _buildSection(
          context,
          '8. VERİ GÜVENLİĞİ',
          'PoM, kişisel verilerinizin güvenliğini sağlamak amacıyla;\n\n'
              '• Tüm veri iletiminde TLS 1.3 şifreleme,\n'
              '• Firebase Security Rules ile erişim kontrolü,\n'
              '• Kimlik bilgilerinin HMAC-SHA256 ile anonim hale getirilmesi,\n'
              '• Düzenli güvenlik denetimleri ve sızma testleri\n\n'
              'uygulamaktadır.',
        ),
        _buildSection(
          context,
          '9. ÇEREZLER VE BENZER TEKNOLOJİLER',
          'Mobil uygulama; oturum yönetimi ve analitik amaçlarıyla yerel depolama (SharedPreferences) '
              'kullanmaktadır. Bu depolama; kullanıcı tercihlerini, oturum belirteçlerini ve önbellek '
              'verilerini içermekte olup reklam amacıyla kullanılmamaktadır.',
        ),
        _buildSection(
          context,
          '10. ÇOCUKLARA AİT VERİLER',
          'PoM hizmetleri 18 yaş altı bireylere yönelik değildir. 18 yaşından küçük olduğunuzu '
              'düşünüyorsanız lütfen uygulamayı kullanmayınız.',
        ),
        _buildSection(
          context,
          '11. POLİTİKA DEĞİŞİKLİKLERİ',
          'Bu Aydınlatma Metni zaman zaman güncellenebilir. Önemli değişiklikler uygulama içi '
              'bildirim veya e-posta yoluyla size iletilecektir. Güncellenmiş metni onaylamanız '
              'talep edilebilir.',
        ),
        _buildSection(
          context,
          '12. İLETİŞİM',
          'Kişisel verilerinizin işlenmesine ilişkin sorularınız veya talepleriniz için:\n\n'
              'Peace of Mind Teknoloji A.Ş.\n'
              'E-posta: kvkk@pom.app\n'
              'Adres: [Şirket Adresi], İstanbul, Türkiye\n\n'
              'Kişisel Veri Koruma Kurumu\'na (KVKK) şikayette bulunma hakkınız saklıdır.',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '"Kabul Et" butonuna basarak yukarıdaki KVKK Aydınlatma Metnini okuduğunuzu, '
            'anladığınızı ve kişisel verilerinizin belirtilen amaçlar doğrultusunda '
            'işlenmesine onay verdiğinizi beyan etmiş olursunuz.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }
}
