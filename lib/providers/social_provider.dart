import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/social_models.dart';
import '../models/user.dart';
import '../models/flashcard.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class SocialProvider with ChangeNotifier {
  final String currentUserId;
  final String currentUserName;
  final String currentUserUsername;

  List<User> _friends = [];
  List<FriendRequest> _pendingRequests = [];
  final Map<String, List<ChatMessage>> _chats = {}; // FriendId -> Messages
  int _unreadMessageCount = 0;
  bool _isLoading = false;

  StreamSubscription? _requestsSubscription;
  StreamSubscription? _unreadSubscription;
  final Set<String> _notifiedIds = {};
  bool _isFirstLoad = true;

  List<User> get friends => _friends;
  List<FriendRequest> get pendingRequests => _pendingRequests;
  int get unreadMessageCount => _unreadMessageCount;
  int get totalNotificationCount => _pendingRequests.length + _unreadMessageCount;
  bool get isLoading => _isLoading;

  SocialProvider({
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserUsername,
  }) {
    _initStreams();
    loadSocialData();
  }

  void _initStreams() {
    final db = FirestoreService.instance;

    // Listen for friend requests
    _requestsSubscription = db.getPendingRequestsStream(currentUserId).listen((requests) {
      if (!_isFirstLoad) {
        for (var req in requests) {
          if (!_notifiedIds.contains(req.id)) {
            NotificationService.instance.showManualNotification(
              'New Friend Request',
              '${req.requesterName} (@${req.requesterUsername}) wants to be your friend!'
            );
            _notifiedIds.add(req.id);
          }
        }
      } else {
        // Collect existing IDs on first load so we don't notify for old stuff
        for (var req in requests) {
          _notifiedIds.add(req.id);
        }
      }
      _pendingRequests = requests;
      notifyListeners();
    });

    // Listen for unread messages
    _unreadSubscription = db.getUnreadMessagesStream(currentUserId).listen((messages) {
      if (!_isFirstLoad) {
        for (var msg in messages) {
          if (!_notifiedIds.contains(msg.id)) {
            NotificationService.instance.showManualNotification(
              'New Message',
              'You received a new message!'
            );
            _notifiedIds.add(msg.id);
          }
        }
      } else {
        // Collect existing IDs on first load
        for (var msg in messages) {
          _notifiedIds.add(msg.id);
        }
        _isFirstLoad = false;
      }
      _unreadMessageCount = messages.length;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _unreadSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadSocialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = FirestoreService.instance;
      
      // Load friends (requests and unread count are now handled by streams)
      _friends = await db.getFriends(currentUserId);

    } catch (e) {
      debugPrint('Error loading social data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markChatAsRead(String friendId) async {
    try {
      await FirestoreService.instance.markMessagesAsRead(currentUserId, friendId);
      // unread count will update automatically via stream
    } catch (e) {
      debugPrint('Error marking chat as read: $e');
    }
  }

  Future<void> sendFriendRequest(User targetUser) async {
    final db = FirestoreService.instance;
    final request = FriendRequest(
      id: const Uuid().v4(),
      requesterId: currentUserId,
      receiverId: targetUser.id,
      requesterName: currentUserName,
      requesterUsername: currentUserUsername,
      status: FriendRequestStatus.pending,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await db.createFriendRequest(request);
    await loadSocialData();
  }

  Future<void> respondToRequest(FriendRequest request, bool accept) async {
    final db = FirestoreService.instance;
    final status = accept ? 'accepted' : 'rejected';
    await db.updateFriendRequestStatus(request.id, status);
    await loadSocialData();
  }

  Future<List<ChatMessage>> getMessages(String friendId) async {
    final db = FirestoreService.instance;
    final messages = await db.getChatHistory(currentUserId, friendId);
    _chats[friendId] = messages;
    return messages;
  }

  Future<void> sendMessage(String friendId, String text, {Flashcard? flashcard, String? deckId, String? deckTitle}) async {
    final db = FirestoreService.instance;
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: currentUserId,
      receiverId: friendId,
      text: text,
      flashcardId: flashcard?.id,
      flashcardQuestion: flashcard?.question,
      deckId: deckId,
      deckTitle: deckTitle,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await db.createMessage(message);
    notifyListeners(); // To trigger UI update if chat is open
  }

  Future<void> shareFlashcard(String friendId, Flashcard card) async {
    await sendMessage(
      friendId, 
      "Hey! Check out this flashcard: ${card.question}", 
      flashcard: card
    );
  }

  Future<void> shareDeck(String friendId, String deckId, String deckTitle) async {
    await sendMessage(
      friendId, 
      "Hey! Check out this flashcard deck: $deckTitle", 
      deckId: deckId,
      deckTitle: deckTitle
    );
  }
}
