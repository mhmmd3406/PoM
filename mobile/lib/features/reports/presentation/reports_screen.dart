import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _activeTab = 'employee';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.darkBg     : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk     : AppColors.lightInk;
    final ink2    = isDark ? AppColors.darkInk2    : AppColors.lightInk2;
    final ink3    = isDark ? AppColors.darkInk3    : AppColors.lightInk3;
    final border  = isDark ? AppColors.borderDark  : AppColors.borderLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final bgAlt   = isDark ? AppColors.darkBgAlt   : AppColors.lightBgAlt;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Shared header + tab pill ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Raporlar',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Icon(Icons.download_outlined, size: 20, color: ink2),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(color: bgAlt, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _ReportTab(label: 'Çalışan', id: 'employee', active: _activeTab, surface: surface, ink: ink, ink3: ink3, onTap: () => setState(() => _activeTab = 'employee')),
                    _ReportTab(label: 'İK',       id: 'hr',       active: _activeTab, surface: surface, ink: ink, ink3: ink3, onTap: () => setState(() => _activeTab = 'hr')),
                    _ReportTab(label: 'Yönetim',  id: 'exec',     active: _activeTab, surface: surface, ink: ink, ink3: ink3, onTap: () => setState(() => _activeTab = 'exec')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Tab content ─────────────────────────────────────────────────
            Expanded(
              child: switch (_activeTab) {
                'hr'   => _HrTab(isDark: isDark, bg: bg, surface: surface, ink: ink, ink2: ink2, ink3: ink3, border: border, divider: divider, bgAlt: bgAlt),
                'exec' => _ExecTab(isDark: isDark, bg: bg, surface: surface, ink: ink, ink2: ink2, ink3: ink3, border: border, divider: divider, bgAlt: bgAlt),
                _      => _EmployeeTab(isDark: isDark, bg: bg, surface: surface, ink: ink, ink2: ink2, ink3: ink3, border: border, divider: divider, bgAlt: bgAlt),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Report tab segment ────────────────────────────────────────────────────────

class _ReportTab extends StatelessWidget {
  const _ReportTab({
    required this.label,
    required this.id,
    required this.active,
    required this.surface,
    required this.ink,
    required this.ink3,
    required this.onTap,
  });

  final String label;
  final String id;
  final String active;
  final Color surface;
  final Color ink;
  final Color ink3;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = active == id;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isActive ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? ink : ink3,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Employee tab ──────────────────────────────────────────────────────────────

class _EmployeeTab extends StatelessWidget {
  const _EmployeeTab({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
    required this.divider,
    required this.bgAlt,
  });

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;
  final Color divider;
  final Color bgAlt;

  static const _dims = [
    (emoji: '😊', label: 'Ruh Hali',  start: 3.2, now: 4.2),
    (emoji: '😌', label: 'Stres',     start: 3.8, now: 3.5),
    (emoji: '🤝', label: 'Takım',     start: 3.6, now: 4.5),
    (emoji: '🌱', label: 'Gelişim',   start: 3.5, now: 4.0),
    (emoji: '⚖️', label: 'Denge',     start: 3.4, now: 4.0),
  ];

  static const _badges = [
    (emoji: '🌱', name: '1 hafta',   earned: true),
    (emoji: '🌿', name: '4 hafta',   earned: true),
    (emoji: '🌳', name: '12 hafta',  earned: true),
    (emoji: '🏆', name: '26 hafta',  earned: false),
    (emoji: '🥇', name: '52 hafta',  earned: false),
    (emoji: '👑', name: '100 hafta', earned: false),
    (emoji: '💎', name: 'Tüm 5',     earned: false),
    (emoji: '🌟', name: '4.5 ort.',  earned: false),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Streak hero
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.amberWash, surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.amber.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.local_fire_department_rounded, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AKTİF SERİ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.amberDeep, letterSpacing: 0.5),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '12 ',
                          style: GoogleFonts.bricolageGrotesque(fontSize: 38, fontWeight: FontWeight.w600, color: ink, height: 1, letterSpacing: -1),
                        ),
                        Text('hafta', style: TextStyle(fontSize: 14, color: ink3, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text('Bir sonraki rozet · 13. hafta · 🥇', style: TextStyle(fontSize: 12, color: ink2)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Personal score trend
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REFAH SKORUN · 12 HAFTA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('4.2', style: GoogleFonts.bricolageGrotesque(fontSize: 32, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.8)),
                            Text('/5', style: TextStyle(fontSize: 14, color: ink3, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.sageWash, borderRadius: BorderRadius.circular(8)),
                    child: Text('↑ +0.6 ortalamadan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.sageDeep)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TwelveWeekPainter(
                    values: const [3.4, 3.5, 3.6, 3.5, 3.7, 3.8, 3.9, 4.0, 3.9, 4.1, 4.0, 4.2],
                    lineColor: AppColors.blue,
                    dividerColor: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Per-dim historical bars
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BOYUT BAZINDA · TARİHSEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
              const SizedBox(height: 12),
              ..._dims.map((d) {
                final delta = d.now - d.start;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 62,
                        child: Text(d.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ink2)),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 22,
                          child: CustomPaint(
                            painter: _DimBarPainter(
                              start: d.start,
                              now: d.now,
                              positive: delta >= 0,
                              bgColor: bgAlt,
                              lineColor: delta >= 0 ? AppColors.sage : AppColors.amber,
                              ink3: ink3,
                              ink: ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: delta >= 0 ? AppColors.sageDeep : ink3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: bgAlt, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('○ 3 ay önce', style: TextStyle(fontSize: 10.5, color: ink3)),
                    Text('● Şimdi', style: TextStyle(fontSize: 10.5, color: ink3)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Badges
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROZETLER · 3/8', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: _badges.map((b) {
                  return Opacity(
                    opacity: b.earned ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: b.earned ? AppColors.amberWash : bgAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: b.earned ? AppColors.amber : border,
                              width: b.earned ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(b.emoji, style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(height: 4),
                        Text(b.name, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ink2), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── HR tab ────────────────────────────────────────────────────────────────────

class _HrTab extends StatelessWidget {
  const _HrTab({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
    required this.divider,
    required this.bgAlt,
  });

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;
  final Color divider;
  final Color bgAlt;

  static const _kpiData = [
    (label: 'Şirket Skoru', value: '3.9', suffix: '/5', delta: '+0.3'),
    (label: 'Katılım',      value: '78',  suffix: '%',  delta: '+12%'),
    (label: 'Toplam Cevap', value: '289', suffix: '',   delta: '+44'),
    (label: 'Aktif Anket',  value: '3',   suffix: '',   delta: ''),
  ];

  static const _deptData = [
    (name: 'Mühendislik', score: '4.2', delta: '+0.2', participation: '92%', positive: true, locked: false),
    (name: 'Ürün',        score: '4.0', delta: '+0.4', participation: '85%', positive: true, locked: false),
    (name: 'Tasarım',     score: '4.3', delta: '+0.1', participation: '95%', positive: true, locked: false),
    (name: 'Satış',       score: '3.5', delta: '−0.3', participation: '64%', positive: false, locked: false),
    (name: 'Müşteri Hiz.',score: '3.2', delta: '−0.5', participation: '71%', positive: false, locked: false),
    (name: 'İK',          score: 'gizli', delta: '—',  participation: '62%', positive: true,  locked: true),
  ];

  static const _alerts = [
    (dept: 'Müşteri Hizmetleri', dim: 'İş Stresi 😌', drop: '−0.5', since: '3 hafta'),
    (dept: 'Satış',              dim: 'İş-Yaşam Dengesi ⚖️', drop: '−0.4', since: '2 hafta'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Weekly summary header
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('19 MAYIS · HAFTA 21', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
                  const SizedBox(height: 2),
                  Text(
                    'Şirket Özeti',
                    style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined, size: 14, color: ink2),
                  const SizedBox(width: 4),
                  Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink2)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // KPI 2×2
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.7,
          children: _kpiData.map((k) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(k.value, style: GoogleFonts.bricolageGrotesque(fontSize: 26, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.6)),
                      if (k.suffix.isNotEmpty)
                        Text(k.suffix, style: TextStyle(fontSize: 12, color: ink3, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (k.delta.isNotEmpty)
                    Text('↑ ${k.delta}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.sageDeep)),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // Dept table
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DEPARTMANLAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
                  Text('n ≥ 10 görünür', style: TextStyle(fontSize: 10.5, color: ink3)),
                ],
              ),
              const SizedBox(height: 10),
              // Table header
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text('Departman', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.3))),
                    SizedBox(width: 44, child: Text('Skor', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.3))),
                    SizedBox(width: 36, child: Text('Δ', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.3))),
                    SizedBox(width: 44, child: Text('Katılım', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.3))),
                  ],
                ),
              ),
              Divider(height: 1, color: divider),
              ..._deptData.asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value;
                final scoreColor = d.locked
                    ? ink3
                    : (d.score == '4.2' || d.score == '4.3' || d.score == '4.0')
                        ? AppColors.sageDeep
                        : d.positive
                            ? ink
                            : AppColors.amberDeep;
                return Container(
                  decoration: BoxDecoration(
                    border: i < _deptData.length - 1 ? Border(bottom: BorderSide(color: divider)) : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(d.name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink))),
                        SizedBox(
                          width: 44,
                          child: d.locked
                              ? Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  Icon(Icons.lock_outline_rounded, size: 11, color: ink3),
                                  const SizedBox(width: 2),
                                  Text('n=8', style: TextStyle(fontSize: 11, color: ink3)),
                                ])
                              : Text(d.score, textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scoreColor)),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            d.delta,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: d.delta.startsWith('+')
                                  ? AppColors.sageDeep
                                  : d.delta.startsWith('−')
                                      ? AppColors.amberDeep
                                      : ink3,
                            ),
                          ),
                        ),
                        SizedBox(width: 44, child: Text(d.participation, textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: ink2))),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Alert cards
        Text('DİKKAT EDİLECEK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink2, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        ..._alerts.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.amberWash,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.notifications_rounded, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a.dept} · ${a.dim}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
                        Text('${a.drop} son ${a.since}da', style: TextStyle(fontSize: 11.5, color: ink2)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: ink2),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Exec tab ──────────────────────────────────────────────────────────────────

class _ExecTab extends StatelessWidget {
  const _ExecTab({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
    required this.divider,
    required this.bgAlt,
  });

  final bool isDark;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;
  final Color divider;
  final Color bgAlt;

  static const _kpiData = [
    (label: 'Aktif', value: '372', suffix: '', delta: '+18%'),
    (label: 'Cevap', value: '1.2K', suffix: '', delta: '+24%'),
    (label: 'Tutma', value: '94',  suffix: '%', delta: '+2pp'),
  ];

  static const _industryData = [
    (label: 'Ruh Hali',  company: 4.2, industry: 3.8),
    (label: 'Stres',     company: 3.5, industry: 3.6),
    (label: 'Takım',     company: 4.5, industry: 4.0),
    (label: 'Gelişim',   company: 4.0, industry: 3.9),
    (label: 'Denge',     company: 4.0, industry: 3.7),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Summary header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2026 · Q2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(
              'Yönetim Özeti',
              style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.5),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 3 KPI tiles
        Row(
          children: _kpiData.asMap().entries.map((entry) {
            final k = entry.value;
            final isLast = entry.key == _kpiData.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(k.value, style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.5)),
                          if (k.suffix.isNotEmpty)
                            Text(k.suffix, style: TextStyle(fontSize: 11, color: ink3)),
                        ],
                      ),
                      Text('↑ ${k.delta}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.sageDeep)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // 12-week time series
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('12 HAFTALIK TREND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
                  Text('Şirket · Sektör', style: TextStyle(fontSize: 11, color: ink3)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TwelveWeekPainter(
                    values: const [3.6, 3.7, 3.6, 3.5, 3.7, 3.8, 3.7, 3.8, 3.9, 3.8, 3.9, 3.9],
                    comparison: const [3.5, 3.5, 3.6, 3.6, 3.5, 3.6, 3.6, 3.6, 3.6, 3.5, 3.6, 3.6],
                    lineColor: AppColors.blue,
                    dividerColor: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    xLabels: const ['H1', 'H4', 'H7', 'H10', 'H12'],
                    xLabelIndices: [0, 3, 6, 9, 11],
                    showGradient: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Industry comparison horizontal bars
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SEKTÖR KARŞILAŞTIRMA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.4)),
              const SizedBox(height: 12),
              Row(children: [
                const SizedBox(width: 8),
                Container(width: 12, height: 12, color: AppColors.blue),
                const SizedBox(width: 4),
                Text('Şirket', style: TextStyle(fontSize: 11, color: ink2)),
                const SizedBox(width: 16),
                Container(width: 12, height: 12, color: ink3.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text('Sektör', style: TextStyle(fontSize: 11, color: ink2)),
              ]),
              const SizedBox(height: 10),
              ..._industryData.map((d) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 64, child: Text(d.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink2))),
                      Expanded(
                        child: Column(
                          children: [
                            _HorizBar(value: d.company, max: 5.0, color: AppColors.blue, bgColor: bgAlt),
                            const SizedBox(height: 3),
                            _HorizBar(value: d.industry, max: 5.0, color: ink3.withValues(alpha: 0.5), bgColor: bgAlt),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 28,
                        child: Text(
                          d.company.toStringAsFixed(1),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _HorizBar extends StatelessWidget {
  const _HorizBar({required this.value, required this.max, required this.color, required this.bgColor});
  final double value;
  final double max;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value / max,
        minHeight: 8,
        backgroundColor: bgColor,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────

class _TwelveWeekPainter extends CustomPainter {
  const _TwelveWeekPainter({
    required this.values,
    this.comparison,
    required this.lineColor,
    required this.dividerColor,
    this.xLabels,
    this.xLabelIndices,
    this.showGradient = false,
  });

  final List<double> values;
  final List<double>? comparison;
  final Color lineColor;
  final Color dividerColor;
  final List<String>? xLabels;
  final List<int>? xLabelIndices;
  final bool showGradient;

  static const _padL = 8.0, _padR = 8.0, _padT = 6.0, _padB = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width - _padL - _padR;
    final ch = size.height - _padT - _padB;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final rangeV = (maxV - minV).clamp(0.5, 5.0);
    final lowY = minV - rangeV * 0.15;
    final highY = maxV + rangeV * 0.15;

    double xOf(int i) => _padL + cw * i / (values.length - 1);
    double yOf(double v) => _padT + ch * (1 - (v - lowY) / (highY - lowY));

    final gridPaint = Paint()..color = dividerColor..strokeWidth = 1.0;
    for (var i = 1; i <= 3; i++) {
      final y = _padT + ch * i / 3;
      canvas.drawLine(Offset(_padL, y), Offset(_padL + cw, y), gridPaint);
    }

    if (showGradient) {
      final grad = Paint()
        ..shader = LinearGradient(
          colors: [lineColor.withValues(alpha: 0.22), lineColor.withValues(alpha: 0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, _padT, size.width, ch));
      final fillPath = Path();
      for (var i = 0; i < values.length; i++) {
        final x = xOf(i); final y = yOf(values[i]);
        if (i == 0) fillPath.moveTo(x, y); else fillPath.lineTo(x, y);
      }
      fillPath.lineTo(xOf(values.length - 1), _padT + ch);
      fillPath.lineTo(xOf(0), _padT + ch);
      fillPath.close();
      canvas.drawPath(fillPath, grad);
    }

    if (comparison != null) {
      final compPath = Path();
      for (var i = 0; i < comparison!.length; i++) {
        final x = xOf(i); final y = yOf(comparison![i]);
        if (i == 0) compPath.moveTo(x, y); else compPath.lineTo(x, y);
      }
      canvas.drawPath(compPath, Paint()
        ..color = dividerColor.withValues(alpha: 0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }

    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = xOf(i); final y = yOf(values[i]);
      if (i == 0) linePath.moveTo(x, y); else linePath.lineTo(x, y);
    }
    canvas.drawPath(linePath, Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    final last = values.length - 1;
    canvas.drawCircle(Offset(xOf(last), yOf(values[last])), 4.5, Paint()..color = lineColor);
    canvas.drawCircle(Offset(xOf(last), yOf(values[last])), 4.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

    if (xLabels != null && xLabelIndices != null) {
      final labelStyle = TextStyle(
        color: dividerColor.withValues(alpha: 1),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      );
      for (var idx = 0; idx < xLabels!.length; idx++) {
        final tp = TextPainter(
          text: TextSpan(text: xLabels![idx], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(xOf(xLabelIndices![idx]) - tp.width / 2, _padT + ch + 6));
      }
    }
  }

  @override
  bool shouldRepaint(_TwelveWeekPainter old) =>
      old.values != values || old.lineColor != lineColor;
}

class _DimBarPainter extends CustomPainter {
  const _DimBarPainter({
    required this.start,
    required this.now,
    required this.positive,
    required this.bgColor,
    required this.lineColor,
    required this.ink3,
    required this.ink,
  });

  final double start;
  final double now;
  final bool positive;
  final Color bgColor;
  final Color lineColor;
  final Color ink3;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = bgColor;
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(6));
    canvas.drawRRect(rrect, bg);

    final startX = start / 5 * size.width;
    final nowX   = now   / 5 * size.width;
    final barY   = size.height / 2 - 2;

    canvas.drawRect(
      Rect.fromLTWH(math.min(startX, nowX), barY, (nowX - startX).abs(), 4),
      Paint()..color = lineColor,
    );

    canvas.drawRect(
      Rect.fromLTWH(startX - 1, size.height * 0.25, 2, size.height * 0.5),
      Paint()..color = ink3.withValues(alpha: 0.5),
    );

    canvas.drawRect(
      Rect.fromLTWH(nowX - 1, size.height * 0.25, 2, size.height * 0.5),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_DimBarPainter old) => false;
}
