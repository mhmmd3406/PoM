import 'package:cloud_firestore/cloud_firestore.dart';

/// Min-N-protected aggregate for one survey + company, written by the
/// `computeSurveyAggregate` Cloud Function to
/// `survey_aggregates/{surveyId}__{companyId}`. firestore.rules restrict reads
/// to that company's members (+ admins). Mirrors the CF doc shape in
/// functions/src/index.ts and scripts/seed_gate_aggregate_data.js.
class GroupAgg {
  const GroupAgg({
    required this.n,
    required this.locked,
    this.overall,
    this.categories = const {},
    this.enps,
  });

  final int n;
  final bool locked; // true when n < min-N → scores suppressed
  final double? overall; // 1–5, null when locked
  final Map<String, double> categories; // category → 1–5, empty when locked
  final int? enps; // −100…+100, null when locked

  factory GroupAgg.fromMap(Map<String, dynamic> m) => GroupAgg(
        n: (m['n'] as num?)?.toInt() ?? 0,
        locked: m['locked'] as bool? ?? true,
        overall: (m['overall'] as num?)?.toDouble(),
        categories: ((m['categories'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
        enps: (m['enps'] as num?)?.toInt(),
      );
}

class SectorAgg extends GroupAgg {
  const SectorAgg({
    required this.industry,
    required this.nCompanies,
    required super.n,
    required super.locked,
    super.overall,
    super.categories,
    super.enps,
  });

  final String industry;
  final int nCompanies;

  factory SectorAgg.fromMap(Map<String, dynamic> m) {
    final g = GroupAgg.fromMap(m);
    return SectorAgg(
      industry: m['industry'] as String? ?? '',
      nCompanies: (m['nCompanies'] as num?)?.toInt() ?? 0,
      n: g.n,
      locked: g.locked,
      overall: g.overall,
      categories: g.categories,
      enps: g.enps,
    );
  }
}

class SurveyAggregate {
  const SurveyAggregate({
    required this.surveyId,
    required this.companyId,
    required this.company,
    this.companyMinN = 15,
    this.departmentMinN = 10,
    this.departments = const {},
    this.sector,
  });

  final String surveyId;
  final String companyId;
  final int companyMinN;
  final int departmentMinN;
  final GroupAgg company;
  final Map<String, GroupAgg> departments;
  final SectorAgg? sector;

  factory SurveyAggregate.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SurveyAggregate(
      surveyId: d['surveyId'] as String? ?? '',
      companyId: d['companyId'] as String? ?? '',
      companyMinN: (d['companyMinN'] as num?)?.toInt() ?? 15,
      departmentMinN: (d['departmentMinN'] as num?)?.toInt() ?? 10,
      company: GroupAgg.fromMap(
          (d['company'] as Map?)?.cast<String, dynamic>() ?? const {}),
      departments: ((d['departments'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(
            k as String, GroupAgg.fromMap((v as Map).cast<String, dynamic>())),
      ),
      sector: d['sector'] != null
          ? SectorAgg.fromMap((d['sector'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}
