import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  static final String _openaiKey = dotenv.get('OPENAI_API_KEY');
  static const String _openaiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> chatWithAssistant(String message, String contextCard) async {
    final response = await http.post(
      Uri.parse(_openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a friendly, encouraging, and expert AI flashcard tutor. '
                'Your student is studying a digital flashcard. Provide highly accurate, '
                'concise, and educational explanations that directly help the student '
                'understand the flashcard being studied.\n\n'
                'Current Flashcard Context:\n$contextCard'
          },
          {
            'role': 'user',
            'content': message
          }
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to communicate with AI Coach: ${response.statusCode}');
    }
  }

  Future<List<Map<String, String>>> generateFlashcards(String content) async {
    final response = await http.post(
      Uri.parse(_openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o', // Using gpt-4o for better performance and speed
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert study assistant. Your task is to generate high-yield flashcards from the provided material. '
                'You MUST intelligently simplify and condense the information to ONLY the most critical, highly testable concepts. '
                'Keep questions extremely concise and direct. '
                'Keep answers extremely brief (1-2 short sentences max) or use concise bullet points. Exclude all fluff and unnecessary context. '
                'Return ONLY a JSON array of objects, where each object has "question" and "answer" keys. '
                'Do not include any other text, markdown blocks, or formatting.'
          },
          {
            'role': 'user',
            'content': 'Generate flashcards for this material:\n\n$content'
          }
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String contentResponse = data['choices'][0]['message']['content'];
      
      // Attempt to parse JSON from the response
      try {
        // Handle potential markdown code blocks in GPT output
        String cleanJson = contentResponse;
        if (cleanJson.contains('```json')) {
          cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
        } else if (cleanJson.contains('```')) {
          cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
        }

        final List<dynamic> jsonList = jsonDecode(cleanJson);
        return jsonList.map((e) => {
          'question': e['question'].toString(),
          'answer': e['answer'].toString(),
        }).toList();
      } catch (e) {
        throw Exception('Failed to parse flashcards: $e');
      }
    } else {
      throw Exception('Failed to communicate with AI service: ${response.statusCode}');
    }
  }

  Future<List<String>> generateDistractors(String question, String answer) async {
    final response = await http.post(
      Uri.parse(_openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert tutor designing a multiple-choice quiz. '
                'I will provide you with a Question and its Correct Answer. '
                'You MUST instantly generate exactly 3 highly plausible, challenging, but fundamentally incorrect wrong answers (distractors). '
                'They should be brief and stylistically matched to the correct answer so they don\'t stand out. '
                'Return ONLY a JSON array of strings, e.g. ["wrong answer 1", "wrong answer 2", "wrong answer 3"]. No markdown.'
          },
          {
            'role': 'user',
            'content': 'Question: $question\nCorrect Answer: $answer'
          }
        ],
        'temperature': 0.8,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String contentResponse = data['choices'][0]['message']['content'];
      
      try {
        if (contentResponse.contains('```json')) {
          contentResponse = contentResponse.split('```json')[1].split('```')[0].trim();
        } else if (contentResponse.contains('```')) {
          contentResponse = contentResponse.split('```')[1].split('```')[0].trim();
        }

        final List<dynamic> jsonList = jsonDecode(contentResponse);
        return jsonList.map((e) => e.toString()).take(3).toList();
      } catch (e) {
        // Fallback fake options if JSON parsing fails
        return ["None of the above", "All of the above", "Not enough information"];
      }
    } else {
      // API error fallback
      return ["None of the above", "All of the above", "Not enough information"];
    }
  }



  Future<String> getStudyRecommendations(String statsSummary) async {
    final response = await http.post(
      Uri.parse(_openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a friendly, encouraging AI Study Coach. '
                'Analyze the student\'s learning statistics and provide exactly 3 bullet points '
                'of highly personalized, actionable advice to help them study better. '
                'Focus on how they can improve, suggest which areas need review, and offer encouragement. '
                'Keep the formatting clean and concise. Do not use complex markdown, just simple bullet points.'
          },
          {
            'role': 'user',
            'content': 'Here are my study statistics:\n$statsSummary'
          }
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get AI study recommendations: ${response.statusCode}');
    }
  }

  Future<List<double>> getEmbedding(String text) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/embeddings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiKey',
      },
      body: jsonEncode({
        'model': 'text-embedding-3-small',
        'input': text,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> embedding = data['data'][0]['embedding'];
      return embedding.map<double>((e) => (e as num).toDouble()).toList();
    } else {
      throw Exception('Failed to generate embedding: ${response.statusCode}');
    }
  }

  Future<List<Map<String, String>>> generateFlashcardsFromRAG(
    List<String> contexts,
    String query,
  ) async {
    final contextString = contexts.map((c) => "Source Text Block:\n$c").join("\n\n");
    final prompt = "You are an expert study assistant. Your task is to generate high-yield study flashcards directly based on the provided context material and user query.\n\n"
        "User query topic: '$query'\n\n"
        "Reference context blocks to extract facts from:\n"
        "$contextString\n\n"
        "Instructions:\n"
        "1. Generate flashcards strictly derived from the facts in the provided reference context blocks.\n"
        "2. Do NOT hallucinate, assume, or extrapolate facts outside the context.\n"
        "3. Keep questions direct and answers brief (1-2 sentences max).\n"
        "4. Return ONLY a JSON array of objects, where each object has 'question' and 'answer' keys. Do not add markdown code blocks or styling.";

    // Re-use the prompt logic in our existing generateFlashcards but we enforce strict context
    final response = await http.post(
      Uri.parse(_openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openaiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert study assistant. Return ONLY a raw JSON array of objects with keys "question" and "answer". Do not wrap in markdown or prefix with other text.'
          },
          {
            'role': 'user',
            'content': prompt
          }
        ],
        'temperature': 0.3, // Lower temperature to prevent hallucinations
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String contentResponse = data['choices'][0]['message']['content'];
      
      try {
        String cleanJson = contentResponse;
        if (cleanJson.contains('```json')) {
          cleanJson = cleanJson.split('```json')[1].split('```')[0].trim();
        } else if (cleanJson.contains('```')) {
          cleanJson = cleanJson.split('```')[1].split('```')[0].trim();
        }

        final List<dynamic> jsonList = jsonDecode(cleanJson);
        return jsonList.map((e) => {
          'question': e['question'].toString(),
          'answer': e['answer'].toString(),
        }).toList();
      } catch (e) {
        throw Exception('Failed to parse RAG flashcards: $e');
      }
    } else {
      throw Exception('Failed to communicate with AI RAG service: ${response.statusCode}');
    }
  }
}


