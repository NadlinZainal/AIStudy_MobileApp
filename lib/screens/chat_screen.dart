import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/social_provider.dart';
import '../providers/deck_provider.dart';
import '../models/user.dart';
import '../models/social_models.dart';
import '../services/firestore_service.dart';
import '../utils/custom_snackbar.dart';
class ChatScreen extends StatefulWidget {
  final User friend;
  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().markChatAsRead(widget.friend.id);
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    await context.read<SocialProvider>().sendMessage(widget.friend.id, text);
    // Mark as read again in case we received something while typing
    if (mounted) {
      context.read<SocialProvider>().markChatAsRead(widget.friend.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialProvider = context.watch<SocialProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.friend.name, style: const TextStyle(fontSize: 16)),
            Text('@${widget.friend.username}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirestoreService.instance.getChatStream(socialProvider.currentUserId, widget.friend.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data ?? [];
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == socialProvider.currentUserId;
                    
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    final time = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (msg.flashcardId != null)
            _buildFlashcardBubble(msg, isMe)
          else if (msg.deckId != null)
            _buildDeckBubble(msg, isMe)
          else
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe 
                    ? Theme.of(context).colorScheme.primary 
                    : (Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF334155) 
                        : Colors.grey[200]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isMe 
                      ? Colors.white 
                      : (Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black87),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardBubble(ChatMessage msg, bool isMe) {
    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.style, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Shared Flashcard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              msg.flashcardQuestion ?? "Shared card",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => _showFlashcardDetailDialog(msg),
            child: const Text('View Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckBubble(ChatMessage msg, bool isMe) {
    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.collections_bookmark, size: 16, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text('Shared Deck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.deckTitle ?? "Shared Deck",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Includes all flashcards',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          TextButton.icon(
            onPressed: () async {
              final deckProvider = context.read<DeckProvider>();
              await deckProvider.importDeck(
                msg.deckId!,
                msg.deckTitle ?? "Imported Deck",
                "Shared by friend",
              );
              if (mounted) {
                CustomSnackBar.show(
                  context,
                  message: 'Deck "${msg.deckTitle}" added to your collection!',
                  type: SnackBarType.success,
                );
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Add to My Decks'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.secondary),
          ),
        ],
      ),
    );
  }

  void _showFlashcardDetailDialog(ChatMessage msg) async {
    final db = FirestoreService.instance;
    final card = await db.getFlashcardById(msg.flashcardId!);

    if (card == null) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Flashcard no longer exists.',
          type: SnackBarType.error,
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        String? selectedDeckId;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final deckProvider = context.watch<DeckProvider>();
            return AlertDialog(
              title: const Text('Flashcard Preview'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('QUESTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text(card.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        Text('ANSWER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text(card.answer),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Save to my deck:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    hint: const Text('Select Deck'),
                    initialValue: selectedDeckId,
                    items: deckProvider.decks.map((deck) {
                      return DropdownMenuItem(
                        value: deck.id,
                        child: Text(deck.title),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedDeckId = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ElevatedButton(
                  onPressed: selectedDeckId == null 
                    ? null 
                    : () async {
                        await deckProvider.addFlashcard(selectedDeckId!, card.question, card.answer);
                        if (context.mounted) {
                          Navigator.pop(context);
                          CustomSnackBar.show(
                            context,
                            message: 'Saved to your deck!',
                            type: SnackBarType.success,
                          );
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Card'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _sendMessage,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
