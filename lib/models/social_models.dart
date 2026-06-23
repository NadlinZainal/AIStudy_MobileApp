enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequest {
  final String id;
  final String requesterId;
  final String receiverId;
  final String requesterName;
  final String requesterUsername;
  final FriendRequestStatus status;
  final int timestamp;

  FriendRequest({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.requesterName,
    required this.requesterUsername,
    this.status = FriendRequestStatus.pending,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'receiverId': receiverId,
      'requesterName': requesterName,
      'requesterUsername': requesterUsername,
      'status': status.name,
      'timestamp': timestamp,
    };
  }

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    return FriendRequest(
      id: map['id'],
      requesterId: map['requesterId'],
      receiverId: map['receiverId'],
      requesterName: map['requesterName'],
      requesterUsername: map['requesterUsername'],
      status: FriendRequestStatus.values.byName(map['status']),
      timestamp: map['timestamp'],
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? flashcardId; // If it's a shared flashcard
  final String? flashcardQuestion; // Cache for display
  final String? deckId; // If it's a shared deck
  final String? deckTitle; // Cache for display
  final int timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.flashcardId,
    this.flashcardQuestion,
    this.deckId,
    this.deckTitle,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'flashcardId': flashcardId,
      'flashcardQuestion': flashcardQuestion,
      'deckId': deckId,
      'deckTitle': deckTitle,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      text: map['text'],
      flashcardId: map['flashcardId'],
      flashcardQuestion: map['flashcardQuestion'],
      deckId: map['deckId'],
      deckTitle: map['deckTitle'],
      timestamp: map['timestamp'],
      isRead: map['isRead'] ?? false,
    );
  }
}
