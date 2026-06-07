import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../insights/providers/insights_provider.dart';
import '../../surveys/providers/surveys_provider.dart';
import '../data/account_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Real stats (no hardcoded values). insights = computeInsights aggregate
    // doc; completedCount = answered-surveys provider. Each degrades gracefully
    // (0 / "—") while loading or when there is no data yet.
    final insights = ref.watch(insightsStreamProvider).valueOrNull;
    final completedCount =
        ref.watch(completedSurveysProvider).valueOrNull?.length ?? 0;
    final checkinCount = insights?.totalCheckins ?? 0;
    final wellbeing = (insights != null && insights.personalAverage > 0)
        ? insights.personalAverage.toStringAsFixed(1)
        : '—';

    final bg      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk      : AppColors.lightInk;
    final ink2    = isDark ? AppColors.darkInk2     : AppColors.lightInk2;
    final ink3    = isDark ? AppColors.darkInk3     : AppColors.lightInk3;
    final border  = isDark ? AppColors.borderDark   : AppColors.borderLight;
    final divider = isDark ? AppColors.dividerDark  : AppColors.dividerLight;
    final bgAlt   = isDark ? AppColors.darkBgAlt    : AppColors.lightBgAlt;

    // Derive initials from display name
    final name     = user?.displayName ?? 'Kullanıcı';
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final email = user?.email ?? '';
    final dept  = user?.department ?? '';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profil',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Icon(Icons.settings_outlined, size: 20, color: ink2),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  // ── User card ────────────────────────────────────────────────
                  GestureDetector(
                    onTap: kDebugMode
                        ? () => _showDebugUserSwitcher(context)
                        : null,
                    child: Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: kDebugMode ? AppColors.amber.withValues(alpha: 0.6) : border,
                        width: kDebugMode ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar with initials
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: user?.avatarUrl != null
                              ? ClipOval(child: Image.network(user!.avatarUrl!, width: 64, height: 64, fit: BoxFit.cover))
                              : Text(
                                  initials,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        // Name + email + chips
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [email, if (dept.isNotEmpty) dept].join(' · '),
                                style: TextStyle(fontSize: 12, color: ink3),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _Chip(
                                    label: _planLabel(user?.role ?? 'free'),
                                    bgColor: isDark ? AppColors.blueSoftDark : AppColors.blueSoft,
                                    fgColor: isDark ? AppColors.blueDark : AppColors.blueDeep,
                                  ),
                                  if (kDebugMode) ...[
                                    const SizedBox(width: 6),
                                    _Chip(
                                      label: '⚙ DEV',
                                      bgColor: AppColors.amber.withValues(alpha: 0.15),
                                      fgColor: AppColors.amber,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),

                  const SizedBox(height: 12),

                  // ── Stats strip ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _StatCell(label: 'CHECK-İN', value: '$checkinCount', ink: ink, ink3: ink3, surface: surface, border: border)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCell(label: 'ANKET', value: '$completedCount', ink: ink, ink3: ink3, surface: surface, border: border)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCell(label: 'REFAH', value: wellbeing, ink: ink, ink3: ink3, surface: surface, border: border)),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ── Bildirimler ──────────────────────────────────────────────
                  _SectionLabel(title: 'Bildirimler', ink3: ink3),
                  _SettingsGroup(surface: surface, border: border, children: [
                    _ToggleRow(label: 'Haftalık check-in hatırlatması', desc: 'Salı 09:00', initialOn: true, ink: ink, ink3: ink3, divider: divider),
                    _ToggleRow(label: 'Yeni anket bildirimleri', desc: 'Push & e-posta', initialOn: true, ink: ink, ink3: ink3, divider: divider),
                    _ToggleRow(label: 'Aylık özet raporu', desc: "Her ayın 1'i", initialOn: false, ink: ink, ink3: ink3, divider: divider),
                    _ToggleRow(label: 'Ürün güncellemeleri', initialOn: false, ink: ink, ink3: ink3, divider: divider, last: true),
                  ]),

                  // ── Görünüm ──────────────────────────────────────────────────
                  _SectionLabel(title: 'Görünüm', ink3: ink3),
                  _SettingsGroup(surface: surface, border: border, children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tema',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _ThemeOption(id: 'light',  icon: '☀️', label: 'Aydınlık', selected: themeMode, bgAlt: bgAlt, onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.light,  isDark: isDark)),
                              const SizedBox(width: 6),
                              Expanded(child: _ThemeOption(id: 'dark',   icon: '🌙', label: 'Karanlık', selected: themeMode, bgAlt: bgAlt, onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark,   isDark: isDark)),
                              const SizedBox(width: 6),
                              Expanded(child: _ThemeOption(id: 'system', icon: '⚙️', label: 'Sistem',   selected: themeMode, bgAlt: bgAlt, onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.system, isDark: isDark)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]),

                  // ── Hesap & Gizlilik ─────────────────────────────────────────
                  _SectionLabel(title: 'Hesap & Gizlilik', ink3: ink3),
                  _SettingsGroup(surface: surface, border: border, children: [
                    _ChevronRow(label: 'KVKK Aydınlatma', desc: 'Versiyon 1.0 · Mart 2026', ink: ink, ink3: ink3, divider: divider, onTap: () => _openUrl(AppConstants.kvkkUrl)),
                    _ChevronRow(label: 'Gizlilik Politikası', ink: ink, ink3: ink3, divider: divider, onTap: () => _openUrl(AppConstants.privacyUrl)),
                    _ChevronRow(label: 'Verilerimi dışa aktar', desc: 'Tüm verilerim · JSON', ink: ink, ink3: ink3, divider: divider, onTap: () => _exportMyData()),
                    _ChevronRow(label: 'Hesabımı sil', desc: 'Tüm verim kalıcı olarak silinir', ink: AppColors.rose, ink3: ink3, divider: divider, onTap: () => _confirmAndDeleteAccount(), last: true),
                  ]),

                  // ── PoM Hakkında ─────────────────────────────────────────────
                  _SectionLabel(title: 'PoM Hakkında', ink3: ink3),
                  _SettingsGroup(surface: surface, border: border, children: [
                    _ChevronRow(label: 'Sürüm', desc: '2.1.0 · Mayıs 2026', ink: ink, ink3: ink3, divider: divider),
                    _ChevronRow(label: 'Destek', ink: ink, ink3: ink3, divider: divider, onTap: () => _openUrl('mailto:${AppConstants.supportEmail}')),
                    _ChevronRow(label: 'Hakkımızda', ink: ink, ink3: ink3, divider: divider, onTap: _showAbout, last: true),
                  ]),

                  const SizedBox(height: 16),

                  // ── Logout button ────────────────────────────────────────────
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(authStateNotifierProvider.notifier).signOut();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: border),
                        foregroundColor: AppColors.rose,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Çıkış yap',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Footer ───────────────────────────────────────────────────
                  Column(
                    children: [
                      Text(
                        'PoM',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ink3,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Made with care · 🇹🇷',
                        style: TextStyle(fontSize: 10, color: ink3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 4,
        onDestinationSelected: (index) {
          const routes = ['/', '/checkin', '/insights', '/surveys', '/profile'];
          context.go(routes[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Check-in',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'İçgörüler',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Anketler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  String _planLabel(String role) => switch (role) {
    'pro'        => 'Pro üye',
    'enterprise' => 'Kurumsal',
    'daas'       => 'DaaS',
    _            => 'Ücretsiz',
  };

  void _showDebugUserSwitcher(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DebugUserSwitcherSheet(
        currentUid: ref.read(currentUserProvider)?.uid ?? '',
        onSelect: (user) {
          ref.read(authStateNotifierProvider.notifier).switchDebugUser(user);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── F3: account & privacy actions ───────────────────────────────────────────

  Future<void> _openUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Bağlantı açılamadı.')));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Bağlantı açılamadı.')));
      }
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabını sil'),
        content: const Text(
          'Hesabın kalıcı olarak silinecek ve kişisel verilerin '
          'anonimleştirilecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Hesabımı sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      // Clearing local auth state makes the router redirect back to /login.
      await ref.read(authStateNotifierProvider.notifier).signOut();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Hesap silinemedi. Lütfen tekrar deneyin.')));
      }
    }
  }

  Future<void> _exportMyData() async {
    final uid = ref.read(currentUserProvider)?.uid;
    final messenger = ScaffoldMessenger.of(context);
    if (uid == null) return;
    try {
      final data = await ref.read(accountRepositoryProvider).exportMyData(uid);
      final json = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Verilerim'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(json)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(const SnackBar(
                    content: Text('Veriler panoya kopyalandı.')));
              },
              child: const Text('Kopyala'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Veriler dışa aktarılamadı.')));
      }
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'PoM — Peace of Mind',
      applicationVersion: '2.1.0',
      applicationLegalese: '© 2026 PoM. Tüm hakları saklıdır.',
      children: const [
        SizedBox(height: 12),
        Text('Anonim çalışan refahı ve ruh hali takip platformu.'),
      ],
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bgColor, required this.fgColor});

  final String label;
  final Color bgColor;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fgColor)),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.ink,
    required this.ink3,
    required this.surface,
    required this.border,
  });

  final String label;
  final String value;
  final Color ink;
  final Color ink3;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.ink3});
  final String title;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.5),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.surface, required this.border, required this.children});
  final Color surface;
  final Color border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatefulWidget {
  const _ToggleRow({
    required this.label,
    this.desc,
    required this.initialOn,
    required this.ink,
    required this.ink3,
    required this.divider,
    this.last = false,
  });

  final String label;
  final String? desc;
  final bool initialOn;
  final Color ink;
  final Color ink3;
  final Color divider;
  final bool last;

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool _on;

  @override
  void initState() {
    super.initState();
    _on = widget.initialOn;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: widget.last ? null : Border(bottom: BorderSide(color: widget.divider, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: widget.ink)),
                  if (widget.desc != null)
                    Text(widget.desc!, style: TextStyle(fontSize: 11.5, color: widget.ink3)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _on = !_on),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 24,
                decoration: BoxDecoration(
                  color: _on ? AppColors.blue : widget.ink3.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: _on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3, offset: const Offset(0, 1))],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({
    required this.label,
    this.desc,
    required this.ink,
    required this.ink3,
    required this.divider,
    this.onTap,
    this.last = false,
  });

  final String label;
  final String? desc;
  final Color ink;
  final Color ink3;
  final Color divider;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: divider, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
                  if (desc != null)
                    Text(desc!, style: TextStyle(fontSize: 11.5, color: ink3)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: ink3),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.id,
    required this.icon,
    required this.label,
    required this.selected,
    required this.bgAlt,
    required this.onTap,
    required this.isDark,
  });

  final String id;
  final String icon;
  final String label;
  final ThemeMode selected;
  final Color bgAlt;
  final VoidCallback onTap;
  final bool isDark;

  static ThemeMode _idToMode(String id) => switch (id) {
    'light'  => ThemeMode.light,
    'dark'   => ThemeMode.dark,
    _        => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    final active = selected == _idToMode(id);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? (isDark ? AppColors.blueWashDark : AppColors.blueSoft) : bgAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.blue : Colors.transparent,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? (isDark ? AppColors.blueDark : AppColors.blueDeep) : (isDark ? AppColors.darkInk2 : AppColors.lightInk2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Debug user switcher bottom sheet ─────────────────────────────────────────

class _DebugUserSwitcherSheet extends StatelessWidget {
  const _DebugUserSwitcherSheet({
    required this.currentUid,
    required this.onSelect,
  });

  final String currentUid;
  final void Function(UserModel) onSelect;

  static const _roleColors = {
    'free':       (bg: Color(0xFFE5E7EB), fg: Color(0xFF374151)),
    'pro':        (bg: Color(0xFFDCFCE7), fg: Color(0xFF166534)),
    'enterprise': (bg: Color(0xFFDBEAFE), fg: Color(0xFF1E40AF)),
    'daas':       (bg: Color(0xFFF3E8FF), fg: Color(0xFF6B21A8)),
  };

  static const _roleLabels = {
    'free': 'Ücretsiz',
    'pro': 'Pro',
    'enterprise': 'Kurumsal',
    'daas': 'DaaS',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚙ DEV',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.amber),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Kullanıcı Değiştir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Seçilen kullanıcının bakış açısıyla uygulamayı keşfet',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),

          // User list
          ...kDebugUsers.map((u) {
            final isActive = u.uid == currentUid;
            final colors = _roleColors[u.role] ?? (bg: const Color(0xFFE5E7EB), fg: const Color(0xFF374151));
            final initials = (u.displayName ?? '?')
                .trim()
                .split(' ')
                .where((w) => w.isNotEmpty)
                .take(2)
                .map((w) => w[0].toUpperCase())
                .join();

            return GestureDetector(
              onTap: isActive ? null : () => onSelect(u),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.blue.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? AppColors.blue : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: isActive ? 0.3 : 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.blueDark : Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.displayName ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${u.email ?? ''}  ·  ${u.department ?? ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleLabels[u.role] ?? u.role,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.fg,
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.blue),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
