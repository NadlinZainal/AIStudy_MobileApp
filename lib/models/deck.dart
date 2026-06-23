class Deck {
  final String id;
  final String userId;
  final String title;
  final String description;
  final int createdAt;
  final bool isFavorite;

  Deck({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.createdAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'createdAt': createdAt,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      id: map['id'],
      userId: map['userId'] ?? '',
      title: map['title'],
      description: map['description'] ?? '',
      createdAt: map['createdAt'],
      isFavorite: map['isFavorite'] == 1,
    );
  }
}

