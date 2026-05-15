import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legalAsync = ref.watch(legalTextsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(title: 'Hesap', children: [
            _Tile(
              icon: Icons.exit_to_app_rounded,
              label: 'Çıkış Yap',
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/');
              },
            ),
            _Tile(
              icon: Icons.delete_outline_rounded,
              label: 'Hesabı Sil',
              color: AppColors.negative,
              onTap: () => _confirmDelete(context),
            ),
          ]),
          const SizedBox(height: 24),
          _Section(title: 'Hukuki', children: [
            _Tile(
              icon: Icons.shield_outlined,
              label: 'KVKK Aydınlatma Metni',
              onTap: () => context.push('/legal/kvkk'),
            ),
            _Tile(
              icon: Icons.policy_outlined,
              label: 'Gizlilik Politikası',
              onTap: () => context.push('/legal/privacy'),
            ),
            _Tile(
              icon: Icons.article_outlined,
              label: 'Kullanım Şartları',
              onTap: () => context.push('/legal/terms'),
            ),
          ]),
          const SizedBox(height: 24),
          legalAsync.whenData((legal) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'KVKK v${legal.kvkkVersion.isEmpty ? "1.0" : legal.kvkkVersion}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          )).value ?? const SizedBox(),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text('Hesabı Sil',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Tüm verileriniz kalıcı olarak silinecek. '
          'Check-in geçmişiniz anonimleştirilecek, '
          'ancak toplu istatistikleri etkilemeyecek.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccount(context);
            },
            child: const Text('Hesabı Sil',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('deleteAccount');
      await fn.call();
      if (context.mounted) context.go('/');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')));
      }
    }
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: children
              .asMap()
              .entries
              .map((e) => Column(
                    children: [
                      e.value,
                      if (e.key < children.length - 1)
                        const Divider(height: 1, color: AppColors.border,
                            indent: 52, endIndent: 16),
                    ],
                  ))
              .toList(),
        ),
      ),
    ],
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? Colors.white70, size: 20),
    title: Text(label,
        style: TextStyle(
            color: color ?? Colors.white70, fontSize: 14)),
    trailing: const Icon(Icons.chevron_right_rounded,
        color: AppColors.textMuted, size: 18),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
  );
}
