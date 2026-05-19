import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

// ─── Static demo data ──────────────────────────────────────────────────────────

class _SurveyItem {
  const _SurveyItem({
    required this.title,
    required this.desc,
    required this.emoji,
    this.questionCount = 0,
    this.responseCount = 0,
    this.participationRate = 0,
    this.deadline,
    this.isDraft = false,
    this.isDone = false,
  });

  final String title;
  final String desc;
  final String emoji;
  final int questionCount;
  final int responseCount;
  final int participationRate;
  final String? deadline;
  final bool isDraft;
  final bool isDone;
}

const _kActiveSurveys = [
  _SurveyItem(
    title: 'Hibrit Çalışma Modeli',
    desc: 'İK tarafından gönderildi',
    emoji: '🏠',
    questionCount: 8,
    responseCount: 124,
    participationRate: 67,
    deadline: '24 May',
  ),
  _SurveyItem(
    title: 'Q2 Refah Anketi',
    desc: 'Çeyreklik gözden geçirme',
    emoji: '🌱',
    questionCount: 12,
    responseCount: 89,
    participationRate: 48,
    deadline: '02 Haz',
  ),
  _SurveyItem(
    title: 'Eğitim Beklentileri',
    desc: 'L&D ekibi',
    emoji: '📚',
    questionCount: 6,
    responseCount: 201,
    participationRate: 87,
    deadline: '20 May',
  ),
];

const _kDraftSurveys = [
  _SurveyItem(
    title: 'Yönetici Geri Bildirim',
    desc: '4 soru hazır',
    emoji: '💬',
    questionCount: 4,
    isDraft: true,
  ),
  _SurveyItem(
    title: 'Ofis Olanakları',
    desc: 'Henüz başlatılmadı',
    emoji: '🪑',
    questionCount: 0,
    isDraft: true,
  ),
];

const _kCompletedSurveys = [
  _SurveyItem(
    title: 'Q1 Refah Anketi',
    desc: '20 Mar - 03 Nis',
    emoji: '✅',
    questionCount: 12,
    responseCount: 312,
    participationRate: 84,
    isDone: true,
  ),
  _SurveyItem(
    title: 'Yeni İşe Alım Deneyimi',
    desc: '15 Şub - 28 Şub',
    emoji: '🌟',
    questionCount: 8,
    responseCount: 28,
    participationRate: 72,
    isDone: true,
  ),
  _SurveyItem(
    title: 'İletişim Tercihleri',
    desc: '01 Şub',
    emoji: '📨',
    questionCount: 5,
    responseCount: 287,
    participationRate: 79,
    isDone: true,
  ),
];

// ─── Screen ────────────────────────────────────────────────────────────────────

class SurveysScreen extends StatefulWidget {
  const SurveysScreen({super.key});

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen> {
  String _activeTab = 'active';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk      : AppColors.lightInk;
    final ink3    = isDark ? AppColors.darkInk3     : AppColors.lightInk3;
    final bgAlt   = isDark ? AppColors.darkBgAlt    : AppColors.lightBgAlt;
    final border  = isDark ? AppColors.borderDark   : AppColors.borderLight;

    final surveys = switch (_activeTab) {
      'draft'     => _kDraftSurveys,
      'completed' => _kCompletedSurveys,
      _           => _kActiveSurveys,
    };

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Anketler',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab pill
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: bgAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _TabSegment(
                      label: 'Aktif',
                      count: _kActiveSurveys.length,
                      active: _activeTab == 'active',
                      surface: surface,
                      ink: ink,
                      ink3: ink3,
                      onTap: () => setState(() => _activeTab = 'active'),
                    ),
                    _TabSegment(
                      label: 'Taslak',
                      count: _kDraftSurveys.length,
                      active: _activeTab == 'draft',
                      surface: surface,
                      ink: ink,
                      ink3: ink3,
                      onTap: () => setState(() => _activeTab = 'draft'),
                    ),
                    _TabSegment(
                      label: 'Tamamlanan',
                      count: _kCompletedSurveys.length,
                      active: _activeTab == 'completed',
                      surface: surface,
                      ink: ink,
                      ink3: ink3,
                      onTap: () => setState(() => _activeTab = 'completed'),
                    ),
                  ],
                ),
              ),
            ),

            // Survey list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: surveys.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _SurveyCard(
                  item: surveys[i],
                  isDark: isDark,
                  surface: surface,
                  border: border,
                  ink: ink,
                  ink3: ink3,
                  bgAlt: bgAlt,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
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
}

// ─── Tab segment ───────────────────────────────────────────────────────────────

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.label,
    required this.count,
    required this.active,
    required this.surface,
    required this.ink,
    required this.ink3,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final Color surface;
  final Color ink;
  final Color ink3;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? ink : ink3,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? AppColors.blueSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.blueDeep : ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Survey card ───────────────────────────────────────────────────────────────

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.item,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
    required this.bgAlt,
  });

  final _SurveyItem item;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;
  final Color bgAlt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bgAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.desc} · ${item.questionCount} soru',
                          style: TextStyle(fontSize: 11.5, color: ink3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: ink3),
                ],
              ),

              // Progress bar (active/completed)
              if (!item.isDraft) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Katılım · ${item.responseCount}/${(item.responseCount / (item.participationRate / 100)).round()}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ink3,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      item.isDone
                          ? '${item.participationRate}% · tamamlandı'
                          : '${item.participationRate}% · ${item.deadline}\'a kadar',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: item.isDone ? AppColors.sageDeep : (isDark ? AppColors.darkInk2 : AppColors.lightInk2),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: item.participationRate / 100,
                    minHeight: 4,
                    backgroundColor: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item.isDone ? AppColors.sage : AppColors.blue,
                    ),
                  ),
                ),
              ],

              // Draft action buttons
              if (item.isDraft) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border),
                          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                          foregroundColor: isDark ? AppColors.darkInk2 : AppColors.lightInk2,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('Düzenle', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('Yayınla', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
