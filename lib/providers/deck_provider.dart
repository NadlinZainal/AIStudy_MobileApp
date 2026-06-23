import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/quiz_session.dart';
import '../services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class DeckProvider with ChangeNotifier {
  List<Deck> _decks = [];
  bool _isLoading = false;
  String? _currentUserId;
  int _studyStreak = 0;
  int _totalFlashcards = 0;
  int _dailyTarget = 0;
  int _dailyCompleted = 0;

  List<Deck> get decks => _decks;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId;
  int get studyStreak => _studyStreak;
  int get totalFlashcards => _totalFlashcards;
  int get dailyTarget => _dailyTarget;
  int get dailyCompleted => _dailyCompleted;
  int get dailyInProgress => (_dailyTarget - _dailyCompleted).clamp(0, _dailyTarget);
  bool get isDailyChallengeCompleted => _dailyTarget > 0 && _dailyCompleted >= _dailyTarget;

  final _uuid = const Uuid();

  DeckProvider();

  void updateUserId(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      if (_currentUserId != null) {
        loadDecks();
      } else {
        _decks = [];
        _studyStreak = 0;
        _totalFlashcards = 0;
        _dailyTarget = 0;
        _dailyCompleted = 0;
        notifyListeners();
      }
    }
  }

  Future<void> loadDecks() async {
    if (_currentUserId == null) return;
    
    _isLoading = true;
    notifyListeners();

    _decks = await FirestoreService.instance.getAllDecks(_currentUserId!);
    await calculateStudyStreak(notify: false);
    await calculateDailyChallengeProgress(notify: false);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDeck(String title, [String description = '']) async {
    if (_currentUserId == null) return;

    final newDeck = Deck(
      id: _uuid.v4(),
      userId: _currentUserId!,
      title: title,
      description: description,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await FirestoreService.instance.createDeck(newDeck);
    await loadDecks();
  }

  Future<void> updateDeck(Deck updatedDeck) async {
    await FirestoreService.instance.updateDeck(updatedDeck);
    await loadDecks();
  }

  Future<void> deleteDeck(String id) async {
    await FirestoreService.instance.deleteDeck(id);
    await loadDecks();
  }

  // Flashcards scoped loading
  Future<List<Flashcard>> getFlashcardsForDeck(String deckId) async {
    return await FirestoreService.instance.getFlashcardsForDeck(deckId);
  }

  Future<List<Deck>> getFavoriteDecks() async {
    if (_currentUserId == null) return [];
    return await FirestoreService.instance.getFavoriteDecks(_currentUserId!);
  }

  Future<void> toggleDeckFavorite(Deck deck) async {
    final updatedDeck = Deck(
      id: deck.id,
      userId: deck.userId,
      title: deck.title,
      description: deck.description,
      createdAt: deck.createdAt,
      isFavorite: !deck.isFavorite,
    );
    await FirestoreService.instance.updateDeck(updatedDeck);
    await loadDecks();
  }

  Future<void> updateFlashcardMastery(Flashcard card, bool isMastered) async {
    final updatedCard = Flashcard(
      id: card.id,
      userId: card.userId,
      deckId: card.deckId,
      question: card.question,
      answer: card.answer,
      createdAt: card.createdAt,
      isFavorite: card.isFavorite,
      isMastered: isMastered,
      interval: card.interval,
      repetitions: card.repetitions,
      easeFactor: card.easeFactor,
      nextReviewDate: card.nextReviewDate,
    );
    await FirestoreService.instance.updateFlashcard(updatedCard);
    notifyListeners();
  }

  Future<Flashcard> updateFlashcardSRS(Flashcard card, int quality) async {
    final updatedCard = card.updateSRS(quality);
    await FirestoreService.instance.updateFlashcard(updatedCard);
    notifyListeners();
    return updatedCard;
  }

  Future<double> getDeckProgress(String deckId) async {
    final flashcards = await getFlashcardsForDeck(deckId);
    if (flashcards.isEmpty) return 0.0;
    int masteredCount = flashcards.where((c) => c.isMastered).length;
    return masteredCount / flashcards.length;
  }

  Future<int> getDueCount(String deckId) async {
    final flashcards = await getFlashcardsForDeck(deckId);
    final now = DateTime.now().millisecondsSinceEpoch;
    return flashcards.where((c) => c.nextReviewDate <= now).length;
  }

  Future<void> addFlashcard(String deckId, String question, String answer) async {
    if (_currentUserId == null) return;

    final newFlashcard = Flashcard(
      id: _uuid.v4(),
      userId: _currentUserId!,
      deckId: deckId,
      question: question,
      answer: answer,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await FirestoreService.instance.createFlashcard(newFlashcard);
    await calculateDailyChallengeProgress(notify: true);
  }

  Future<void> importDeck(String sourceDeckId, String title, [String description = '']) async {
    if (_currentUserId == null) return;
    
    // 1. Get source cards
    final cards = await FirestoreService.instance.getFlashcardsForDeck(sourceDeckId);
    
    // 2. Create new deck
    final newDeckId = _uuid.v4();
    final newDeck = Deck(
      id: newDeckId,
      userId: _currentUserId!,
      title: "$title (Imported)",
      description: description,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await FirestoreService.instance.createDeck(newDeck);
    
    // 3. Add cards
    final List<Map<String, String>> qnaList = cards.map((c) => {
      'question': c.question,
      'answer': c.answer,
    }).toList();
    
    await addMultipleFlashcards(newDeckId, qnaList);
    await loadDecks();
  }

  Future<void> addMultipleFlashcards(String deckId, List<Map<String, String>> qnaList) async {
    if (_currentUserId == null) return;

    for (var qna in qnaList) {
      final newFlashcard = Flashcard(
        id: _uuid.v4(),
        userId: _currentUserId!,
        deckId: deckId,
        question: qna['question'] ?? '',
        answer: qna['answer'] ?? '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await FirestoreService.instance.createFlashcard(newFlashcard);
    }
    await calculateDailyChallengeProgress(notify: true);
  }

  Future<void> updateFlashcard(Flashcard updatedFlashcard) async {
    await FirestoreService.instance.updateFlashcard(updatedFlashcard);
    notifyListeners();
  }

  Future<void> deleteFlashcard(String id) async {
    await FirestoreService.instance.deleteFlashcard(id);
    await calculateDailyChallengeProgress(notify: true);
  }

  // --- Quiz Sessions ---
  Future<void> saveQuizSession(String userId, String deckId, int score, int totalCards, [int duration = 0]) async {
    final session = QuizSession(
      id: _uuid.v4(),
      userId: userId,
      deckId: deckId,
      score: score,
      totalCards: totalCards,
      createdAt: DateTime.now(),
      duration: duration,
    );
    await FirestoreService.instance.createQuizSession(session);
    await calculateStudyStreak(notify: false);
    await calculateDailyChallengeProgress(notify: true);
  }

  Future<void> calculateStudyStreak({bool notify = true}) async {
    if (_currentUserId == null) {
      _studyStreak = 0;
      if (notify) notifyListeners();
      return;
    }
    
    try {
      final sessions = await FirestoreService.instance.getQuizSessionsForUser(_currentUserId!);
      _studyStreak = _computeStreakFromSessions(sessions);
    } catch (e) {
      debugPrint("Error calculating streak: $e");
      _studyStreak = 0;
    }
    if (notify) notifyListeners();
  }

  int _computeStreakFromSessions(List<QuizSession> sessions) {
    if (sessions.isEmpty) return 0;

    // Filter to unique local dates
    final dates = sessions.map((s) {
      final localDate = s.createdAt.toLocal();
      return DateTime(localDate.year, localDate.month, localDate.day);
    }).toSet().toList();

    // Sort in descending order (most recent first)
    dates.sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // If the most recent study session is not today nor yesterday, the streak is 0
    if (dates.first != today && dates.first != yesterday) {
      return 0;
    }

    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      final current = dates[i];
      final next = dates[i + 1];
      final expectedPrevDay = DateTime(current.year, current.month, current.day - 1);

      if (next == expectedPrevDay) {
        streak++;
      } else if (next.isBefore(expectedPrevDay)) {
        break; // streak broken
      }
      // If next is same as current, we do nothing and continue
    }
    return streak;
  }

  Future<void> calculateDailyChallengeProgress({bool notify = true}) async {
    if (_currentUserId == null) {
      _totalFlashcards = 0;
      _dailyTarget = 0;
      _dailyCompleted = 0;
      if (notify) notifyListeners();
      return;
    }

    try {
      int total = 0;
      for (var deck in _decks) {
        final cards = await getFlashcardsForDeck(deck.id);
        total += cards.length;
      }
      _totalFlashcards = total;

      if (_totalFlashcards == 0) {
        _dailyTarget = 0;
      } else {
        int calculatedTarget = (_totalFlashcards * 0.15).round().clamp(5, 25);
        _dailyTarget = calculatedTarget > _totalFlashcards ? _totalFlashcards : calculatedTarget;
      }

      final sessions = await FirestoreService.instance.getQuizSessionsForUser(_currentUserId!);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int completedToday = 0;
      for (var session in sessions) {
        final localDate = session.createdAt.toLocal();
        final sessionDay = DateTime(localDate.year, localDate.month, localDate.day);
        if (sessionDay == today) {
          completedToday += session.totalCards;
        }
      }
      _dailyCompleted = completedToday;
    } catch (e) {
      debugPrint("Error calculating daily challenge: $e");
    }

    if (notify) notifyListeners();
  }

  Future<List<QuizSession>> getQuizSessionsForDeck(String deckId, String userId) async {
    return await FirestoreService.instance.getQuizSessionsForDeck(deckId, userId);
  }

  Future<List<QuizSession>> getQuizSessionsForUser() async {
    if (_currentUserId == null) return [];
    return await FirestoreService.instance.getQuizSessionsForUser(_currentUserId!);
  }

  Future<Map<String, int>> getTotalStats() async {
    if (_currentUserId == null) return {'totalCards': 0, 'masteredCards': 0};
    
    int total = 0;
    int mastered = 0;
    
    // We fetch all cards for all decks to get the real count
    for (var deck in _decks) {
      final cards = await getFlashcardsForDeck(deck.id);
      total += cards.length;
      mastered += cards.where((c) => c.isMastered).length;
    }
    
    return {
      'totalCards': total,
      'masteredCards': mastered,
    };
  }

  Future<Map<String, int>> getDetailedCardStats() async {
    if (_currentUserId == null) {
      return {
        'totalCards': 0,
        'masteredCards': 0,
        'learningCards': 0,
        'dueCards': 0,
      };
    }

    int total = 0;
    int mastered = 0;
    int learning = 0;
    int due = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var deck in _decks) {
      final cards = await getFlashcardsForDeck(deck.id);
      total += cards.length;
      mastered += cards.where((c) => c.isMastered).length;
      learning += cards.where((c) => c.repetitions > 0 && !c.isMastered).length;
      due += cards.where((c) => c.nextReviewDate <= now).length;
    }

    return {
      'totalCards': total,
      'masteredCards': mastered,
      'learningCards': learning,
      'dueCards': due,
    };
  }

  Future<DeckStats> getDeckStats(String deckId) async {
    final flashcards = await getFlashcardsForDeck(deckId);
    if (flashcards.isEmpty) {
      return DeckStats(totalCount: 0, masteredCount: 0, dueCount: 0, progress: 0.0);
    }
    final total = flashcards.length;
    final mastered = flashcards.where((c) => c.isMastered).length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = flashcards.where((c) => c.nextReviewDate <= now).length;
    return DeckStats(
      totalCount: total,
      masteredCount: mastered,
      dueCount: due,
      progress: mastered / total,
    );
  }
}

class DeckStats {
  final int totalCount;
  final int masteredCount;
  final int dueCount;
  final double progress;

  DeckStats({
    required this.totalCount,
    required this.masteredCount,
    required this.dueCount,
    required this.progress,
  });
}


