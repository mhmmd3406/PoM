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
  });

  final String id;
  final String text;
  final SurveyQuestionType type;
  final String hint;

  factory SurveyQuestion.fromMap(Map<String, dynamic> m) => SurveyQuestion(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        type: SurveyQuestionTypeX.fromString(m['type'] as String? ?? ''),
        hint: m['hint'] as String? ?? '',
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
      deadline: d['deadline'] != null
          ? (d['deadline'] as Timestamp).toDate()
          : null,
      createdAt: d['created_at'] != null
          ? (d['created_at'] as Timestamp).toDate()
          : null,
    );
  }
}
