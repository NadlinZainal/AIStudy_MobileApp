import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class QuizApiService {
  static final String _apiKey = dotenv.get('QUIZAPI_KEY', fallback: '');
  static final String _baseUrl = dotenv.get('QUIZAPI_URL', fallback: 'https://quizapi.io/api/v1/questions');

  Future<List<QuizApiQuestion>> fetchQuestions({
    String category = 'Linux',
    String difficulty = 'Easy',
    int limit = 5,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'apiKey': _apiKey,
      'category': category,
      'difficulty': difficulty,
      'limit': limit.toString(),
    });

    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('QuizAPI request failed with status ${response.statusCode}');
    }

    final List<dynamic> decoded = jsonDecode(response.body);
    return decoded.map((item) => QuizApiQuestion.fromJson(item)).toList();
  }
}

class QuizApiQuestion {
  final int id;
  final String question;
  final Map<String, String> answers;
  final Map<String, bool> correctAnswers;
  final bool multipleCorrectAnswers;
  final String? explanation;

  QuizApiQuestion({
    required this.id,
    required this.question,
    required this.answers,
    required this.correctAnswers,
    required this.multipleCorrectAnswers,
    this.explanation,
  });

  factory QuizApiQuestion.fromJson(Map<String, dynamic> json) {
    final answers = <String, String>{};
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    rawAnswers.forEach((key, value) {
      if (value != null) {
        answers[key] = value.toString();
      }
    });

    final correctAnswers = <String, bool>{};
    final rawCorrect = json['correct_answers'] as Map<String, dynamic>? ?? {};
    rawCorrect.forEach((key, value) {
      correctAnswers[key] = value.toString().toLowerCase().contains('true');
    });

    return QuizApiQuestion(
      id: json['id'] as int,
      question: json['question'] as String,
      answers: answers,
      correctAnswers: correctAnswers,
      multipleCorrectAnswers: json['multiple_correct_answers'] == 'true',
      explanation: json['explanation'] as String?,
    );
  }

  List<String> get choices => answers.values.toList();

  List<String> get correctChoiceKeys {
    return correctAnswers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.replaceAll('_correct', ''))
        .toList();
  }

  String get correctAnswer {
    final correctKeys = correctChoiceKeys;
    if (correctKeys.isEmpty) {
      return '';
    }
    final answersList = <String>[];
    for (final key in correctKeys) {
      if (answers.containsKey(key)) {
        answersList.add(answers[key]!);
      }
    }
    return answersList.join(' | ');
  }
}
