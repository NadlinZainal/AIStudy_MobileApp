import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_aistudy/screens/quiz_screen.dart';

void main() {
  group('QuizScreen Space-Fill Heuristic Tests', () {
    test('Empty sentence handling', () {
      final data = QuizScreen.generateFillInBlankData('');
      expect(data.blankedSentence, equals(''));
      expect(data.blankedWords, isEmpty);
    });

    test('Single word answer blanks the word', () {
      final data = QuizScreen.generateFillInBlankData('Forensics');
      expect(data.blankedSentence, equals('_______'));
      expect(data.blankedWords, equals(['forensics']));
    });

    test('Medium answer (5-9 words) blanks out 2 longest unique content words', () {
      // "Digital forensics is a branch of science" -> 7 words
      // Stop words: 'is', 'a', 'of'
      // Candidates: 'digital', 'forensics', 'branch', 'science'
      // Longest content words: 'forensics' (9), 'digital' (7), 'science' (7), 'branch' (6)
      // Top 2: 'forensics', 'digital' (or 'science' if order/length matches)
      final data = QuizScreen.generateFillInBlankData('Digital forensics is a branch of science');
      
      expect(data.blankedWords.length, equals(2));
      expect(data.blankedWords, contains('forensics'));
      expect(data.blankedWords, contains('digital'));
      
      // Blanked indices will be 0 and 1, so the sentence should start with two blanks
      expect(data.blankedSentence.startsWith('_______ _______ is a branch of science'), isTrue);
    });

    test('Long answer (>= 10 words) blanks out 3 longest unique content words', () {
      final sentence = 'digital forensic is a science that analyzes digital evidence and data';
      final data = QuizScreen.generateFillInBlankData(sentence);
      
      expect(data.blankedWords.length, equals(3));
      expect(data.blankedWords, contains('forensic'));
      expect(data.blankedWords, contains('analyzes'));
      expect(data.blankedWords, contains('evidence'));
      
      expect(data.blankedSentence, equals('digital _______ is a science that _______ digital _______ and data'));
    });

    test('Punctuation is preserved around blanks', () {
      final sentence = 'Forensics, specifically digital, is crucial.';
      final data = QuizScreen.generateFillInBlankData(sentence);
      
      // Clean candidate words: forensics (9), specifically (11), digital (7), crucial (7)
      // Longest: specifically (11), forensics (9)
      // Indices: 0 (Forensics,), 1 (specifically)
      // Expected sentence start: "_______, _______ digital, is crucial."
      expect(data.blankedWords, contains('specifically'));
      expect(data.blankedWords, contains('forensics'));
      expect(data.blankedSentence, startsWith('_______, _______ digital, is crucial.'));
    });
  });

  group('QuizScreen Space-Fill Correctness Grading Tests', () {
    const correctAnswer = 'digital forensic is a science that analyzes digital evidence and data';
    // Target words: 'forensic', 'analyzes', 'evidence'

    test('Exact match of the full sentence is correct', () {
      expect(QuizScreen.isFillInBlankCorrect(
        'digital forensic is a science that analyzes digital evidence and data', 
        correctAnswer
      ), isTrue);
    });

    test('Close match of the full sentence with slight typo is correct', () {
      expect(QuizScreen.isFillInBlankCorrect(
        'digital forensics is a science that analyzes digital evidence and data', 
        correctAnswer
      ), isTrue);
    });

    test('Comma-separated list of target words is correct', () {
      expect(QuizScreen.isFillInBlankCorrect(
        'forensic, analyzes, evidence', 
        correctAnswer
      ), isTrue);
    });

    test('Comma-separated list with slight typos is correct', () {
      expect(QuizScreen.isFillInBlankCorrect(
        'forensic, analyze, evidence', 
        correctAnswer
      ), isTrue);
    });

    test('Space-separated list of target words is correct', () {
      expect(QuizScreen.isFillInBlankCorrect(
        'forensic analyzes evidence', 
        correctAnswer
      ), isTrue);
    });

    test('Incorrect target words are marked incorrect', () {
      expect(QuizScreen.isFillInBlankCorrect(
        'forensic, math, evidence', 
        correctAnswer
      ), isFalse);
    });

    test('Incomplete target words are marked incorrect', () {
      expect(QuizScreen.isFillInBlankCorrect(
        'forensic, analyzes', 
        correctAnswer
      ), isFalse);
    });
  });
}
