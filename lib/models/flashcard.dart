class Flashcard {
  final String id;
  final String userId;
  final String deckId;
  final String question;
  final String answer;
  final int createdAt;
  final bool isFavorite;
  final bool isMastered;
  final int interval;
  final int repetitions;
  final double easeFactor;
  final int nextReviewDate;

  Flashcard({
    required this.id,
    required this.userId,
    required this.deckId,
    required this.question,
    required this.answer,
    required this.createdAt,
    this.isFavorite = false,
    this.isMastered = false,
    this.interval = 0,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.nextReviewDate = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'deckId': deckId,
      'question': question,
      'answer': answer,
      'createdAt': createdAt,
      'isFavorite': isFavorite ? 1 : 0,
      'isMastered': isMastered ? 1 : 0,
      'interval': interval,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'nextReviewDate': nextReviewDate,
    };
  }

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'],
      userId: map['userId'] ?? '',
      deckId: map['deckId'],
      question: map['question'],
      answer: map['answer'],
      createdAt: map['createdAt'],
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
      isMastered: map['isMastered'] == 1 || map['isMastered'] == true,
      interval: map['interval']?.toInt() ?? 0,
      repetitions: map['repetitions']?.toInt() ?? 0,
      easeFactor: map['easeFactor']?.toDouble() ?? 2.5,
      nextReviewDate: map['nextReviewDate']?.toInt() ?? 0,
    );
  }

  Flashcard updateSRS(int quality) {
    int newRepetitions;
    int newInterval;
    double newEaseFactor;

    if (quality < 3) {
      newRepetitions = 0;
      newInterval = 1;
    } else {
      if (repetitions == 0) {
        newInterval = 1;
      } else if (repetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (interval * easeFactor).round();
      }
      newRepetitions = repetitions + 1;
    }

    newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEaseFactor < 1.3) {
      newEaseFactor = 1.3;
    }

    final now = DateTime.now();
    final nextDate = now.add(Duration(days: newInterval));
    final newNextReviewDate = nextDate.millisecondsSinceEpoch;

    return Flashcard(
      id: id,
      userId: userId,
      deckId: deckId,
      question: question,
      answer: answer,
      createdAt: createdAt,
      isFavorite: isFavorite,
      isMastered: quality >= 3,
      interval: newInterval,
      repetitions: newRepetitions,
      easeFactor: newEaseFactor,
      nextReviewDate: newNextReviewDate,
    );
  }
}

