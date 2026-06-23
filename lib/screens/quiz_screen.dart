import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../providers/deck_provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import '../services/quiz_api_service.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';

enum QuestionType {
  multipleChoice,
  trueFalse,
  fillInBlank,
  shortAnswer,
}

enum QuizDifficulty {
  easy,
  medium,
  hard,
}

class QuizQuestion {
  final Flashcard flashcard;
  final QuestionType type;
  final List<String> options; // For MC and TF
  final String correctAnswer; // The correct answer text
  final String statement; // Specifically for TF statements

  QuizQuestion({
    required this.flashcard,
    required this.type,
    required this.options,
    required this.correctAnswer,
    this.statement = '',
  });
}

class QuizScreen extends StatefulWidget {
  final Deck deck;
  final List<Flashcard> flashcards;

  const QuizScreen({super.key, required this.deck, required this.flashcards});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  late List<Flashcard> _shuffledCards;
  final List<QuizQuestion> _quizQuestions = [];
  bool _hasAnswered = false;
  String? _selectedAnswer;
  List<String> _currentOptions = [];
  bool _isPreloading = true;
  final Map<String, List<String>> _preloadedDistractors = {};
  final List<Future<void>> _pendingSrsUpdates = [];

  // Adaptive Difficulty Fields
  QuizDifficulty _currentDifficulty = QuizDifficulty.easy;
  int _consecutiveCorrect = 0;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isOverrideApplicable = false;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _shuffledCards = List.from(widget.flashcards)..shuffle();
    _preloadAllDistractors();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _preloadAllDistractors() async {
    final aiService = AIService();
    final quizApiService = QuizApiService();
    
    // Batch generate distractors for user cards
    await Future.wait(_shuffledCards.map((card) async {
      try {
        final distractors = await aiService.generateDistractors(card.question, card.answer);
        _preloadedDistractors[card.id] = distractors;
      } catch (e) {
        _preloadedDistractors[card.id] = ["None of the above", "All of the above", "Not enough information"];
      }
    }));

    // Fetch Quiz API questions for additional breadth if wanted
    List<QuizApiQuestion> apiQuestions;
    try {
      apiQuestions = await quizApiService.fetchQuestions(
        category: 'Linux',
        difficulty: 'Easy',
        limit: 3,
      );
    } catch (_) {
      apiQuestions = [];
    }

    // Merge API questions into shuffled cards pool as special API flashcards
    for (final apiQuestion in apiQuestions) {
      final apiFlashcard = Flashcard(
        id: 'api-${apiQuestion.id}',
        userId: '',
        deckId: widget.deck.id,
        question: apiQuestion.question,
        answer: apiQuestion.correctAnswer,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      _shuffledCards.add(apiFlashcard);
      _preloadedDistractors[apiFlashcard.id] = apiQuestion.choices
          .where((choice) => choice != apiQuestion.correctAnswer && choice.isNotEmpty)
          .toList();
    }
    
    _shuffledCards.shuffle();
    
    if (mounted) {
      setState(() {
        _isPreloading = false;
        _prepareCurrentTask();
      });
    }
  }

  QuizQuestion _buildAdaptiveQuestion(Flashcard card, QuizDifficulty difficulty) {
    final rand = math.Random();
    
    if (difficulty == QuizDifficulty.easy) {
      // 30% chance True/False statement, 70% Multiple Choice
      final isTrueFalse = rand.nextDouble() < 0.3;
      if (isTrueFalse) {
        final isStatementTrue = rand.nextBool();
        String statement;
        String correctAnswer;
        
        if (isStatementTrue) {
          statement = "Is it correct that the answer to '${card.question}' is '${card.answer}'?";
          correctAnswer = 'True';
        } else {
          final distractors = _preloadedDistractors[card.id] ?? ["None of the above", "All of the above", "Not enough information"];
          final wrongAns = distractors.first;
          statement = "Is it correct that the answer to '${card.question}' is '$wrongAns'?";
          correctAnswer = 'False';
        }
        
        return QuizQuestion(
          flashcard: card,
          type: QuestionType.trueFalse,
          options: const ['True', 'False'],
          correctAnswer: correctAnswer,
          statement: statement,
        );
      } else {
        // Multiple Choice
        final distractors = _preloadedDistractors[card.id] ?? ["None of the above", "All of the above", "Not enough information"];
        final options = [card.answer, ...distractors.take(3)].toList()..shuffle();
        return QuizQuestion(
          flashcard: card,
          type: QuestionType.multipleChoice,
          options: options,
          correctAnswer: card.answer,
        );
      }
    } else if (difficulty == QuizDifficulty.medium) {
      // Fill in the Blank
      return QuizQuestion(
        flashcard: card,
        type: QuestionType.fillInBlank,
        options: const [],
        correctAnswer: card.answer,
      );
    } else {
      // Hard: Short Answer
      return QuizQuestion(
        flashcard: card,
        type: QuestionType.shortAnswer,
        options: const [],
        correctAnswer: card.answer,
      );
    }
  }

  void _prepareCurrentTask() {
    if (_shuffledCards.isEmpty) return;
    
    final card = _shuffledCards[_currentIndex];
    final question = _buildAdaptiveQuestion(card, _currentDifficulty);
    
    if (_quizQuestions.length <= _currentIndex) {
      _quizQuestions.add(question);
    } else {
      _quizQuestions[_currentIndex] = question;
    }

    _hasAnswered = false;
    _selectedAnswer = null;
    _textController.clear();
    _isOverrideApplicable = false;
    _currentOptions = List.of(question.options);
  }

  void _handleOptionSelected(String option) {
    if (_hasAnswered) return;
    
    final question = _quizQuestions[_currentIndex];
    final isCorrect = option == question.correctAnswer;

    setState(() {
      _selectedAnswer = option;
      _hasAnswered = true;
    });

    _processAnswerResult(isCorrect);
  }

  void _submitTextAnswer() {
    if (_hasAnswered) return;
    _focusNode.unfocus();

    final question = _quizQuestions[_currentIndex];
    final answerText = _textController.text;
    final isCorrect = isCloseMatch(answerText, question.correctAnswer);

    setState(() {
      _hasAnswered = true;
      _selectedAnswer = answerText;
      if (!isCorrect) {
        _isOverrideApplicable = true;
      }
    });

    _processAnswerResult(isCorrect);
  }

  void _overrideGrading() {
    if (!_hasAnswered || !_isOverrideApplicable) return;

    setState(() {
      _score++;
      _consecutiveCorrect++;
      _isOverrideApplicable = false;
      
      if (_consecutiveCorrect >= 2) {
        _levelUpDifficulty();
      }
    });

    final card = _quizQuestions[_currentIndex].flashcard;
    if (card.id.isNotEmpty && !card.id.startsWith('api-')) {
      final updatedCard = card.updateSRS(4);
      for (int i = 0; i < _shuffledCards.length; i++) {
        if (_shuffledCards[i].id == card.id) {
          _shuffledCards[i] = updatedCard;
        }
      }
      final future = context.read<DeckProvider>().updateFlashcardSRS(card, 4);
      _pendingSrsUpdates.add(future);
    }
  }

  void _processAnswerResult(bool isCorrect) {
    if (isCorrect) {
      _score++;
      _consecutiveCorrect++;
      if (_consecutiveCorrect >= 2) {
        _levelUpDifficulty();
      }
    } else {
      _consecutiveCorrect = 0;
      _levelDownDifficulty();
    }

    final card = _quizQuestions[_currentIndex].flashcard;
    if (card.id.isNotEmpty && !card.id.startsWith('api-')) {
      final updatedCard = card.updateSRS(isCorrect ? 4 : 1);
      for (int i = 0; i < _shuffledCards.length; i++) {
        if (_shuffledCards[i].id == card.id) {
          _shuffledCards[i] = updatedCard;
        }
      }
      final future = context.read<DeckProvider>().updateFlashcardSRS(card, isCorrect ? 4 : 1);
      _pendingSrsUpdates.add(future);
    }
  }

  void _levelUpDifficulty() {
    if (_currentDifficulty == QuizDifficulty.easy) {
      setState(() {
        _currentDifficulty = QuizDifficulty.medium;
        _consecutiveCorrect = 0;
      });
      _showLevelChangeBanner("Leveled up to Medium! 🚀", Colors.orange);
    } else if (_currentDifficulty == QuizDifficulty.medium) {
      setState(() {
        _currentDifficulty = QuizDifficulty.hard;
        _consecutiveCorrect = 0;
      });
      _showLevelChangeBanner("Leveled up to Hard! 🔥", Colors.redAccent);
    }
  }

  void _levelDownDifficulty() {
    if (_currentDifficulty == QuizDifficulty.hard) {
      setState(() {
        _currentDifficulty = QuizDifficulty.medium;
      });
      _showLevelChangeBanner("Difficulty adjusted to Medium 💡", Colors.orange);
    } else if (_currentDifficulty == QuizDifficulty.medium) {
      setState(() {
        _currentDifficulty = QuizDifficulty.easy;
      });
      _showLevelChangeBanner("Difficulty adjusted to Easy 💡", Colors.green);
    }
  }

  void _showLevelChangeBanner(String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      ),
    );
  }

  void _nextTask() async {
    if (_currentIndex < _shuffledCards.length - 1) {
      setState(() {
        _currentIndex++;
        _prepareCurrentTask();
      });
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        await Future.wait(_pendingSrsUpdates);
      } catch (e) {
        debugPrint("Error waiting for quiz updates: $e");
      }

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        
        final userId = context.read<AuthProvider>().user?.id;
        if (userId != null) {
          final duration = DateTime.now().difference(_startTime).inSeconds;
          await context.read<DeckProvider>().saveQuizSession(
            userId,
            widget.deck.id,
            _score,
            _shuffledCards.length,
            duration,
          );
        }
        _showResultDialog();
      }
    }
  }

  bool isCloseMatch(String input, String expected) {
    final cleanInput = input.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final cleanExpected = expected.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    if (cleanInput == cleanExpected) return true;

    final distance = _levenshtein(cleanInput, cleanExpected);
    final maxLength = math.max(cleanInput.length, cleanExpected.length);
    if (maxLength == 0) return true;
    final similarity = 1.0 - (distance / maxLength);
    return similarity >= 0.85; // Slightly tighten the similarity threshold to 85% for better accuracy
  }

  int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1,
          math.min(
            v0[j + 1] + 1,
            v0[j] + cost,
          ),
        );
      }
      v0 = List<int>.from(v1);
    }
    return v0[s2.length];
  }

  String getBlankHint(String answer) {
    final words = answer.split(' ');
    final hintWords = words.map((word) {
      if (word.length <= 2) {
        return word;
      }
      final firstChar = word.substring(0, 1);
      final lastChar = word.substring(word.length - 1);
      final blanks = '_' * (word.length - 2);
      final formattedBlanks = blanks.split('').join(' ');
      return '$firstChar $formattedBlanks $lastChar';
    });
    return hintWords.join('   ');
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Study Session Complete!'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school, size: 60, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              '$_score / ${_shuffledCards.length}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text('Correct Answers', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Text(
              _score == _shuffledCards.length 
                ? 'Incredible mastery! 🎉' 
                : _score > _shuffledCards.length / 2 
                  ? 'Great study session! 🚀' 
                  : 'Keep reviewing! 💪',
              style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Go Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _score = 0;
                _hasAnswered = false;
                _selectedAnswer = null;
                _shuffledCards.shuffle();
                _quizQuestions.clear();
                _currentDifficulty = QuizDifficulty.easy;
                _consecutiveCorrect = 0;
                _startTime = DateTime.now();
                _prepareCurrentTask();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Study Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyPill(QuizDifficulty difficulty) {
    Color color;
    String label;
    IconData icon;

    switch (difficulty) {
      case QuizDifficulty.easy:
        color = Colors.green;
        label = 'Easy';
        icon = Icons.bolt_outlined;
        break;
      case QuizDifficulty.medium:
        color = Colors.orange;
        label = 'Medium';
        icon = Icons.bolt;
        break;
      case QuizDifficulty.hard:
        color = Colors.redAccent;
        label = 'Hard';
        icon = Icons.offline_bolt_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            'Difficulty: $label',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Flashcard card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'QUESTION',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            card.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    final currentQuestion = _quizQuestions[_currentIndex];
    return Column(
      children: _currentOptions.map((option) {
        final isSelected = _selectedAnswer == option;
        final isCorrect = option == currentQuestion.correctAnswer;
        
        Color backgroundColor = Theme.of(context).colorScheme.surface;
        Color borderColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey[300]!;
        Color textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87;
        
        if (_hasAnswered) {
          if (isCorrect) {
            backgroundColor = Colors.green[50]!;
            borderColor = Colors.green;
            textColor = Colors.green[700]!;
          } else if (isSelected) {
            backgroundColor = Colors.red[50]!;
            borderColor = Colors.red;
            textColor = Colors.red[700]!;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => _handleOptionSelected(option),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (_hasAnswered && isCorrect)
                    const Icon(Icons.check_circle, color: Colors.green),
                  if (_hasAnswered && isSelected && !isCorrect)
                    const Icon(Icons.cancel, color: Colors.red),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrueFalseOptions(QuizQuestion question) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Text(
            question.statement,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        Row(
          children: ['True', 'False'].map((option) {
            final isSelected = _selectedAnswer == option;
            final isCorrect = option == question.correctAnswer;
            
            Color backgroundColor = Theme.of(context).colorScheme.surface;
            Color borderColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : Colors.grey[300]!;
            Color textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87;
            
            if (_hasAnswered) {
              if (isCorrect) {
                backgroundColor = Colors.green[50]!;
                borderColor = Colors.green;
                textColor = Colors.green[700]!;
              } else if (isSelected) {
                backgroundColor = Colors.red[50]!;
                borderColor = Colors.red;
                textColor = Colors.red[700]!;
              }
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: InkWell(
                  onTap: () => _handleOptionSelected(option),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option == 'True' ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: _hasAnswered
                              ? (isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey))
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFillInBlank(QuizQuestion question) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Text(
                'LETTER HINT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                getBlankHint(question.correctAnswer),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                  fontFamily: 'Courier',
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          enabled: !_hasAnswered,
          decoration: InputDecoration(
            hintText: 'Type your answer...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onSubmitted: (_) => _submitTextAnswer(),
        ),
        const SizedBox(height: 16),
        if (!_hasAnswered)
          ElevatedButton.icon(
            onPressed: _submitTextAnswer,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit Answer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          )
        else
          _buildPostAnswerFeedback(question),
      ],
    );
  }

  Widget _buildShortAnswer(QuizQuestion question) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          enabled: !_hasAnswered,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Write your short answer...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onSubmitted: (_) => _submitTextAnswer(),
        ),
        const SizedBox(height: 16),
        if (!_hasAnswered)
          ElevatedButton.icon(
            onPressed: _submitTextAnswer,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit Answer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          )
        else
          _buildPostAnswerFeedback(question),
      ],
    );
  }

  Widget _buildPostAnswerFeedback(QuizQuestion question) {
    final theme = Theme.of(context);
    final isCorrect = _selectedAnswer != null && isCloseMatch(_selectedAnswer!, question.correctAnswer);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct!' : 'Incorrect',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCorrect ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your Answer: "${_selectedAnswer ?? ""}"',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Correct Answer: "${question.correctAnswer}"',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!isCorrect && _isOverrideApplicable) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _overrideGrading,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('My answer was correct, override'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdaptiveInputArea(QuizQuestion question) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return _buildOptions();
      case QuestionType.trueFalse:
        return _buildTrueFalseOptions(question);
      case QuestionType.fillInBlank:
        return _buildFillInBlank(question);
      case QuestionType.shortAnswer:
        return _buildShortAnswer(question);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledCards.isEmpty) return const Scaffold(body: Center(child: Text("No cards")));

    if (_isPreloading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Preparing Quiz...'),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeCap: StrokeCap.round, strokeWidth: 4),
              ),
              const SizedBox(height: 32),
              Text(
                'AIStudy is engineering your quiz...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Generating adaptive questions',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _quizQuestions[_currentIndex];
    final progress = (_currentIndex + 1) / _shuffledCards.length;
    final card = currentQuestion.flashcard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptive Quiz'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentIndex + 1} of ${_shuffledCards.length}',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                      const SizedBox(width: 2),
                      Text(
                        '$_consecutiveCorrect',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: _buildDifficultyPill(_currentDifficulty)),
              const SizedBox(height: 20),
              _buildQuestionCard(card),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildAdaptiveInputArea(currentQuestion),
                ),
              ),
              if (_hasAnswered)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton(
                    onPressed: _nextTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Next Question',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                const SizedBox(height: 72),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
