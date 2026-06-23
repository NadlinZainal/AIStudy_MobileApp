class QuizSession {
  final String id;
  final String userId;
  final String deckId;
  final int score;
  final int totalCards;
  final DateTime createdAt;
  final int duration; // in seconds

  QuizSession({
    required this.id,
    required this.userId,
    required this.deckId,
    required this.score,
    required this.totalCards,
    required this.createdAt,
    this.duration = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'deckId': deckId,
      'score': score,
      'totalCards': totalCards,
      'createdAt': createdAt.toIso8601String(),
      'duration': duration,
    };
  }

  factory QuizSession.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        return DateTime.parse(value);
      }
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      try {
        // Duck-typing support for Firestore Timestamp
        return value.toDate();
      } catch (_) {}
      return DateTime.now();
    }

    return QuizSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      deckId: map['deckId'] ?? '',
      score: map['score']?.toInt() ?? 0,
      totalCards: map['totalCards']?.toInt() ?? 0,
      createdAt: parseDateTime(map['createdAt']),
      duration: map['duration']?.toInt() ?? 0,
    );
  }
}
