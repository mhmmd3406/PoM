import 'package:cloud_firestore/cloud_firestore.dart';

/// One anonymized, min-N-cleared group (a company or a sector) in the
/// cross-company survey benchmark. Written by computeSurveyAggregate into
/// `survey_benchmarks/{surveyId}`; readable by any authenticated user (it carries
/// no individuals and no sub-min-N groups). Powers the "Şirket Karşılaştırması"
/// survey comparison (Sen vs selected companies / sector / all).
class BenchGroup {
  const BenchGroup({
    required this.key,
    required this.label,
    required this.industry,
    required this.n,
    required this.overall,
    required this.categories,
    required this.enps,
  });

  final String key; // companyId or industry
  final String label; // company name or "<industry> sektörü"
  final String industry;
  final int n;
  final double? overall;
  final Map<String, double> categories; // 12 survey categories → 1–5
  final int? enps;
}

class SurveyBenchmark {
  const SurveyBenchmark({
    required this.surveyId,
    required this.companyMinN,
    required this.companies,
    required this.sectors,
  });

  final String surveyId;
  final int companyMinN;
  final List<BenchGroup> companies; // sorted high → low by overall
  final Map<String, BenchGroup> sectors; // industry → group

  factory SurveyBenchmark.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    Map<String, double> cats(dynamic m) =>
        ((m as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        );

    final companies = ((d['companies'] as List?) ?? const [])
        .map((c) {
          final m = (c as Map).cast<String, dynamic>();
          return BenchGroup(
            key: m['companyId'] as String? ?? '',
            label: m['name'] as String? ?? (m['companyId'] as String? ?? ''),
            industry: m['industry'] as String? ?? '',
            n: (m['n'] as num?)?.toInt() ?? 0,
            overall: (m['overall'] as num?)?.toDouble(),
            categories: cats(m['categories']),
            enps: (m['enps'] as num?)?.toInt(),
          );
        })
        .toList();

    final sectors = ((d['sectors'] as Map?) ?? const {}).map((k, v) {
      final m = (v as Map).cast<String, dynamic>();
      final industry = m['industry'] as String? ?? k as String;
      return MapEntry(
        k as String,
        BenchGroup(
          key: industry,
          label: '$industry sektörü',
          industry: industry,
          n: (m['n'] as num?)?.toInt() ?? 0,
          overall: (m['overall'] as num?)?.toDouble(),
          categories: cats(m['categories']),
          enps: (m['enps'] as num?)?.toInt(),
        ),
      );
    });

    return SurveyBenchmark(
      surveyId: d['surveyId'] as String? ?? doc.id,
      companyMinN: (d['companyMinN'] as num?)?.toInt() ?? 15,
      companies: companies,
      sectors: sectors,
    );
  }
}
