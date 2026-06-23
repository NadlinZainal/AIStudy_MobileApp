import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/quiz_session.dart';
import '../models/social_models.dart';
import '../models/user.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users ---
  Future<void> upsertUser(User user) async {
    await _db.collection('users').doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteUser(String id) async {
    final batch = _db.batch();
    
    // 1. Delete user doc
    batch.delete(_db.collection('users').doc(id));
    
    // 2. Delete all decks owned by the user
    final decksSnap = await _db.collection('decks').where('userId', isEqualTo: id).get();
    for (var doc in decksSnap.docs) {
      batch.delete(doc.reference);
    }
    
    // 3. Delete all flashcards owned by the user
    final cardsSnap = await _db.collection('flashcards').where('userId', isEqualTo: id).get();
    for (var doc in cardsSnap.docs) {
      batch.delete(doc.reference);
    }
    
    // 4. Delete all quiz sessions owned by the user
    final sessionsSnap = await _db.collection('quiz_sessions').where('userId', isEqualTo: id).get();
    for (var doc in sessionsSnap.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  Future<User?> getUserById(String id) async {
    final doc = await _db.collection('users').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return User.fromMap(doc.data()!);
    }
    return null;
  }

  Future<List<User>> searchUsers(String query) async {
    // Note: Firestore doesn't support generic 'LIKE' text search natively.
    // For a basic implementation, we can do an exact match or a prefix search on username.
    // To support a simple prefix search:
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    
    // We will pull all users and filter locally since there won't be millions of users in this demo.
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((d) => User.fromMap(d.data()))
        .where((u) => 
          u.username.toLowerCase().contains(lowerQuery) || 
          u.name.toLowerCase().contains(lowerQuery)
        ).toList();
  }

  // --- Decks ---
  Future<void> createDeck(Deck deck) async {
    await _db.collection('decks').doc(deck.id).set(deck.toMap());
  }

  Future<Deck?> getDeck(String id) async {
    final doc = await _db.collection('decks').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Deck.fromMap(doc.data()!);
    }
    return null;
  }

  Future<List<Deck>> getAllDecks(String userId) async {
    final snapshot = await _db.collection('decks')
      .where('userId', isEqualTo: userId)
      .get();
    final list = snapshot.docs.map((d) => Deck.fromMap(d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<Deck>> getFavoriteDecks(String userId) async {
    final snapshot = await _db.collection('decks')
      .where('userId', isEqualTo: userId)
      .where('isFavorite', isEqualTo: 1)
      .get();
    final list = snapshot.docs.map((d) => Deck.fromMap(d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> updateDeck(Deck deck) async {
    await _db.collection('decks').doc(deck.id).update(deck.toMap());
  }

  Future<void> deleteDeck(String id) async {
    // We also need to delete associated flashcards
    final flashcards = await getFlashcardsForDeck(id);
    final batch = _db.batch();
    
    batch.delete(_db.collection('decks').doc(id));
    for (var card in flashcards) {
      batch.delete(_db.collection('flashcards').doc(card.id));
    }
    await batch.commit();
  }

  // --- Flashcards ---
  Future<void> createFlashcard(Flashcard flashcard) async {
    await _db.collection('flashcards').doc(flashcard.id).set(flashcard.toMap());
  }

  Future<Flashcard?> getFlashcardById(String id) async {
    final doc = await _db.collection('flashcards').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Flashcard.fromMap(doc.data()!);
    }
    return null;
  }

  Future<List<Flashcard>> getFlashcardsForDeck(String deckId) async {
    final snapshot = await _db.collection('flashcards')
      .where('deckId', isEqualTo: deckId)
      .get();
    final list = snapshot.docs.map((d) => Flashcard.fromMap(d.data())).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<List<Flashcard>> getFavoriteFlashcards(String userId) async {
    final snapshot = await _db.collection('flashcards')
      .where('userId', isEqualTo: userId)
      .where('isFavorite', isEqualTo: 1)
      .get();
    final list = snapshot.docs.map((d) => Flashcard.fromMap(d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> updateFlashcard(Flashcard flashcard) async {
    await _db.collection('flashcards').doc(flashcard.id).update(flashcard.toMap());
  }

  Future<void> deleteFlashcard(String id) async {
    await _db.collection('flashcards').doc(id).delete();
  }

  Future<void> deleteFlashcardsForDeck(String deckId) async {
    final flashcards = await getFlashcardsForDeck(deckId);
    final batch = _db.batch();
    for (var card in flashcards) {
      batch.delete(_db.collection('flashcards').doc(card.id));
    }
    await batch.commit();
  }

  // --- Friend Requests ---
  Future<void> createFriendRequest(FriendRequest request) async {
    await _db.collection('friend_requests').doc(request.id).set(request.toMap());
  }

  Future<List<FriendRequest>> getPendingRequests(String userId) async {
    final snapshot = await _db.collection('friend_requests')
      .where('receiverId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .get();
    return snapshot.docs.map((d) => FriendRequest.fromMap(d.data())).toList();
  }

  Future<List<User>> getFriends(String userId) async {
    final reqQuery = await _db.collection('friend_requests')
      .where('requesterId', isEqualTo: userId)
      .where('status', isEqualTo: 'accepted')
      .get();
    final recQuery = await _db.collection('friend_requests')
      .where('receiverId', isEqualTo: userId)
      .where('status', isEqualTo: 'accepted')
      .get();

    final allRequests = [...reqQuery.docs, ...recQuery.docs];
    
    List<User> friendList = [];
    for (var doc in allRequests) {
      final req = FriendRequest.fromMap(doc.data());
      final friendId = req.requesterId == userId ? req.receiverId : req.requesterId;
      final friendDoc = await _db.collection('users').doc(friendId).get();
      if (friendDoc.exists && friendDoc.data() != null) {
        friendList.add(User.fromMap(friendDoc.data()!));
      }
    }
    return friendList;
  }

  Future<void> updateFriendRequestStatus(String id, String status) async {
    await _db.collection('friend_requests').doc(id).update({'status': status});
  }

  // --- Chat Messages ---
  Future<void> createMessage(ChatMessage message) async {
    await _db.collection('chat_messages').doc(message.id).set(message.toMap());
  }

  Future<List<ChatMessage>> getChatHistory(String user1Id, String user2Id) async {
    // Because Firestore 'OR' queries exist but require specific structure, 
    // it's easier to retrieve both sent and received separately and combine,
    // OR create a combined conversational channel ID (e.g. `user1_user2` alphabetically sorted).
    // Let's implement the two-query approach for simplicity.
    
    final sentQuery = await _db.collection('chat_messages')
      .where('senderId', isEqualTo: user1Id)
      .where('receiverId', isEqualTo: user2Id)
      .get();
      
    final receivedQuery = await _db.collection('chat_messages')
      .where('senderId', isEqualTo: user2Id)
      .where('receiverId', isEqualTo: user1Id)
      .get();
      
    final messages = [
      ...sentQuery.docs.map((d) => ChatMessage.fromMap(d.data())),
      ...receivedQuery.docs.map((d) => ChatMessage.fromMap(d.data()))
    ];
    
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Future<int> getUnreadMessagesCount(String userId) async {
    final snapshot = await _db.collection('chat_messages')
      .where('receiverId', isEqualTo: userId)
      .where('isRead', isEqualTo: false)
      .get();
    return snapshot.docs.length;
  }

  Future<void> markMessagesAsRead(String userId, String senderId) async {
    final snapshot = await _db.collection('chat_messages')
      .where('receiverId', isEqualTo: userId)
      .where('senderId', isEqualTo: senderId)
      .where('isRead', isEqualTo: false)
      .get();
    
    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // --- Streams (Real-time updates) ---

  Stream<List<FriendRequest>> getPendingRequestsStream(String userId) {
    return _db.collection('friend_requests')
      .where('receiverId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((d) => FriendRequest.fromMap(d.data()))
        .toList());
  }

  Stream<List<ChatMessage>> getUnreadMessagesStream(String userId) {
    return _db.collection('chat_messages')
      .where('receiverId', isEqualTo: userId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((d) => ChatMessage.fromMap(d.data()))
        .toList());
  }

  Stream<List<ChatMessage>> getChatStream(String user1Id, String user2Id) {
    // Note: This only covers one direction. For a full chat, 
    // we need to combine streams or use a composite filter.
    // For simplicity, we'll implement this as a combined listener in the Provider.
    return _db.collection('chat_messages')
      .where('receiverId', whereIn: [user1Id, user2Id])
      .snapshots()
      .map((snapshot) {
        final messages = snapshot.docs
          .map((d) => ChatMessage.fromMap(d.data()))
          .where((m) => 
            (m.senderId == user1Id && m.receiverId == user2Id) ||
            (m.senderId == user2Id && m.receiverId == user1Id)
          ).toList();
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return messages;
      });
  }

  // --- Quiz Sessions ---
  Future<void> createQuizSession(QuizSession session) async {
    await _db.collection('quiz_sessions').doc(session.id).set(session.toMap());
  }

  Future<List<QuizSession>> getQuizSessionsForDeck(String deckId, String userId) async {
    final snapshot = await _db.collection('quiz_sessions')
      .where('deckId', isEqualTo: deckId)
      .where('userId', isEqualTo: userId)
      .get();
      
    final list = snapshot.docs.map((d) => QuizSession.fromMap(d.data())).toList();
    // Sort in Dart mapping newest first to avoid missing composite index
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<QuizSession>> getQuizSessionsForUser(String userId) async {
    final snapshot = await _db.collection('quiz_sessions')
      .where('userId', isEqualTo: userId)
      .get();
      
    final list = snapshot.docs.map((d) => QuizSession.fromMap(d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
