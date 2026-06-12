import 'package:flutter_test/flutter_test.dart';
import 'package:pom_app/features/surveys/data/survey_model.dart';
import 'package:pom_app/features/surveys/data/survey_scoring.dart';

void main() {
  group('normalizeAnswer', () {
    test('scale5 passes through, clamps out-of-range to null', () {
      expect(normalizeAnswer(4, SurveyQuestionType.scale5), 4.0);
      expect(normalizeAnswer(1, SurveyQuestionType.scale5), 1.0);
      expect(normalizeAnswer(0, SurveyQuestionType.scale5), isNull);
      expect(normalizeAnswer(6, SurveyQuestionType.scale5), isNull);
    });

    test('emoji5 is 0-indexed on mobile and maps to 1..5', () {
      expect(normalizeAnswer(0, SurveyQuestionType.emoji5), 1.0);
      expect(normalizeAnswer(4, SurveyQuestionType.emoji5), 5.0);
      expect(normalizeAnswer(5, SurveyQuestionType.emoji5), isNull);
    });

    test('scale10 maps 0..10 linearly to 1..5', () {
      expect(normalizeAnswer(0, SurveyQuestionType.scale10), 1.0);
      expect(normalizeAnswer(10, SurveyQuestionType.scale10), 5.0);
      expect(normalizeAnswer(5, SurveyQuestionType.scale10), 3.0);
    });

    test('yesno / trueFalse respect reverseScore', () {
      expect(normalizeAnswer(true, SurveyQuestionType.yesno), 5.0);
      expect(normalizeAnswer(false, SurveyQuestionType.yesno), 1.0);
      expect(
          normalizeAnswer(true, SurveyQuestionType.yesno, reverseScore: true),
          1.0);
      expect(
          normalizeAnswer(false, SurveyQuestionType.yesno, reverseScore: true),
          5.0);
    });

    test('text and null are unscored', () {
      expect(normalizeAnswer('hello', SurveyQuestionType.text), isNull);
      expect(normalizeAnswer(null, SurveyQuestionType.scale5), isNull);
    });
  });

  group('calcCategoryScores', () {
    final questions = [
      const SurveyQuestion(
          id: 'q1',
          text: '',
          type: SurveyQuestionType.scale5,
          category: 'Stres'),
      const SurveyQuestion(
          id: 'q2',
          text: '',
          type: SurveyQuestionType.scale5,
          category: 'Stres'),
      const SurveyQuestion(
          id: 'q3',
          text: '',
          type: SurveyQuestionType.yesno,
          category: 'Güven'),
      // No category → excluded.
      const SurveyQuestion(
          id: 'q4', text: '', type: SurveyQuestionType.scale5),
    ];

    test('averages normalizable answers per category', () {
      final cats = calcCategoryScores(questions, {
        'q1': 4,
        'q2': 2,
        'q3': true,
        'q4': 5,
      });
      final byName = {for (final c in cats) c.name: c};
      expect(byName['Stres']!.score, 3.0); // (4+2)/2
      expect(byName['Güven']!.score, 5.0); // yes → 5
      expect(byName.containsKey(null), isFalse);
      expect(cats.length, 2);
    });

    test('categories with no scored answers are dropped', () {
      final cats = calcCategoryScores(questions, {'q4': 5});
      expect(cats, isEmpty);
    });
  });

  group('classifyEnps', () {
    final questions = [
      const SurveyQuestion(
          id: 'nps',
          text: '',
          type: SurveyQuestionType.scale10,
          isEnps: true),
    ];

    test('classifies promoter / passive / detractor', () {
      expect(classifyEnps(questions, {'nps': 9})!.group, EnpsGroup.promoter);
      expect(classifyEnps(questions, {'nps': 7})!.group, EnpsGroup.passive);
      expect(classifyEnps(questions, {'nps': 6})!.group, EnpsGroup.detractor);
      expect(classifyEnps(questions, {'nps': 9})!.score, 9);
    });

    test('returns null without an answered scale10 eNPS question', () {
      expect(classifyEnps(questions, {}), isNull);
      expect(
          classifyEnps([
            const SurveyQuestion(
                id: 'x', text: '', type: SurveyQuestionType.scale5)
          ], {
            'x': 5
          }),
          isNull);
    });
  });

  group('scoreBand', () {
    test('maps score ranges to labels', () {
      expect(scoreBand(4.5).label, 'Çok Yüksek');
      expect(scoreBand(3.5).label, 'Yüksek');
      expect(scoreBand(3.0).label, 'Orta');
      expect(scoreBand(2.0).label, 'Düşük');
      expect(scoreBand(1.5).label, 'Çok Düşük');
    });
  });
}
