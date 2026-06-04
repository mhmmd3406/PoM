import 'package:cloud_firestore/cloud_firestore.dart';

enum SurveyStatus { draft, active, closed }

enum SurveyQuestionType { emoji5, scale10, scale5, yesno, trueFalse, text }

extension SurveyStatusX on SurveyStatus {
  static SurveyStatus fromString(String s) => switch (s) {
        'active' => SurveyStatus.active,
        'closed' => SurveyStatus.closed,
        _ => SurveyStatus.draft,
      };
}

extension SurveyQuestionTypeX on SurveyQuestionType {
  static SurveyQuestionType fromString(String s) => switch (s) {
        'scale10'   => SurveyQuestionType.scale10,
        'scale5'    => SurveyQuestionType.scale5,
        'yesno'     => SurveyQuestionType.yesno,
        'trueFalse' => SurveyQuestionType.trueFalse,
        'text'      => SurveyQuestionType.text,
        _           => SurveyQuestionType.emoji5,
      };
}

class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.hint = '',
    this.category = '',
    this.reverseScore = false,
    this.isEnps = false,
  });

  final String id;
  final String text;
  final SurveyQuestionType type;
  final String hint;
  // Groups this question into a named category for aggregate scoring.
  final String category;
  // For yesno/trueFalse: Evet=1,Hayır=5 when true (negatively-framed questions,
  // e.g. "Mobbing yaşadınız mı?"). Default false → Evet=5, Hayır=1.
  final bool reverseScore;
  // Marks the designated eNPS question (must be scale10, 0–10).
  final bool isEnps;

  factory SurveyQuestion.fromMap(Map<String, dynamic> m) => SurveyQuestion(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        type: SurveyQuestionTypeX.fromString(m['type'] as String? ?? ''),
        hint: m['hint'] as String? ?? '',
        category: m['category'] as String? ?? '',
        reverseScore: m['reverseScore'] as bool? ?? false,
        isEnps: m['isEnps'] as bool? ?? false,
      );
}

class SurveyModel {
  const SurveyModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.emoji,
    required this.status,
    required this.questions,
    required this.minNThreshold,
    required this.responseCount,
    this.isGate = false,
    this.isMandatory = false,
    this.deadline,
    this.createdAt,
  });

  final String id;
  // '__admin__' = platform-wide survey visible to all users
  final String companyId;
  final String title;
  final String description;
  final String emoji;
  final SurveyStatus status;
  final List<SurveyQuestion> questions;
  final int minNThreshold;
  final int responseCount;
  // Shown to users as a full-screen gate on app launch until completed.
  final bool isGate;
  // When true the skip button is hidden; users must complete before accessing app.
  final bool isMandatory;
  final DateTime? deadline;
  final DateTime? createdAt;

  bool get isAdminSurvey => companyId == '__admin__';
  int get questionCount => questions.length;

  factory SurveyModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SurveyModel(
      id: doc.id,
      companyId: d['companyId'] as String? ?? '__admin__',
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '📊',
      status: SurveyStatusX.fromString(d['status'] as String? ?? 'draft'),
      questions: (d['questions'] as List<dynamic>? ?? [])
          .map((q) => SurveyQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
      minNThreshold: d['minNThreshold'] as int? ?? 5,
      responseCount: d['responseCount'] as int? ?? 0,
      isGate: d['isGate'] as bool? ?? false,
      isMandatory: d['isMandatory'] as bool? ?? false,
      deadline: d['deadline'] != null
          ? (d['deadline'] as Timestamp).toDate()
          : null,
      createdAt: d['created_at'] != null
          ? (d['created_at'] as Timestamp).toDate()
          : null,
    );
  }
}
