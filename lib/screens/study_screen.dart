import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../widgets/chat_action_button.dart';

class StudyScreen extends StatefulWidget {
  final Deck deck;
  final List<Flashcard> flashcards;

  const StudyScreen({super.key, required this.deck, required this.flashcards});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _currentIndex = 0;
  int _score = 0;
  late List<Flashcard> _shuffledCards;
  bool _isFlipped = false;
  GlobalKey<FlipCardState> _cardKey = GlobalKey<FlipCardState>();

  @override
  void initState() {
    super.initState();
    _shuffledCards = List.from(widget.flashcards)..shuffle();
  }

  void _nextCard(int quality) {
    if (quality >= 3) _score++;
    
    final currentCard = _shuffledCards[_currentIndex];
    final updatedCard = currentCard.updateSRS(quality);

    // Update local list items to prevent stale interval calculations
    for (int i = 0; i < _shuffledCards.length; i++) {
      if (_shuffledCards[i].id == currentCard.id) {
        _shuffledCards[i] = updatedCard;
      }
    }

    final srsUpdateFuture = context.read<DeckProvider>().updateFlashcardSRS(currentCard, quality);

    setState(() {
      _isFlipped = false;
      _cardKey = GlobalKey<FlipCardState>(); // Recreate key to force reset next card to front

      if (quality < 3) {
        // Push this updated card to the end of the list to try again later in this session
        _shuffledCards.add(updatedCard);
      }

      if (_currentIndex < _shuffledCards.length - 1) {
        _currentIndex++;
      } else {
        _showCompletionFlow(srsUpdateFuture);
      }
    });
  }

  Future<void> _showCompletionFlow(Future<dynamic> pendingUpdate) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await pendingUpdate;
    } catch (e) {
      debugPrint("Error updating last card: $e");
    }

    if (mounted) {
      Navigator.pop(context); // Close loading indicator
      
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        await context.read<DeckProvider>().saveQuizSession(
          userId,
          widget.deck.id,
          _score,
          _shuffledCards.length,
        );
      }
      _showResultDialog();
    }
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
            const Text('Cards Mastered', style: TextStyle(color: Colors.grey)),
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
                _isFlipped = false;
                _cardKey = GlobalKey<FlipCardState>();
                _shuffledCards.shuffle();
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

  int _estimateNextInterval(Flashcard card, int quality) {
    if (quality < 3) {
      return 1;
    }
    int reps = card.repetitions;
    if (reps == 0) {
      return 1;
    } else if (reps == 1) {
      return 6;
    } else {
      double ef = card.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      if (ef < 1.3) ef = 1.3;
      return (card.interval * ef).round();
    }
  }

  String _formatInterval(int days) {
    if (days >= 30) {
      final months = (days / 30).round();
      return '${months}mo';
    }
    return '${days}d';
  }

  Widget _buildSRSButton({
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledCards.isEmpty) return const Scaffold(body: Center(child: Text("No cards")));

    final card = _shuffledCards[_currentIndex];
    final progress = (_currentIndex + 1) / _shuffledCards.length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Session'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionIconButton(
              icon: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
              size: 44,
              onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => _ChatOverlay(card: card),
              );
            },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
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
            Text(
              'Card ${_currentIndex + 1} of ${_shuffledCards.length}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            FlipCard(
              key: _cardKey,
              direction: FlipDirection.HORIZONTAL,
              onFlipDone: (isFront) {
                setState(() {
                  _isFlipped = !isFront;
                });
              },
              front: Container(
                height: 380,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'THE MYSTERY',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          card.question,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26, 
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Icon(
                          Icons.visibility_outlined,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to reveal',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              back: Container(
                height: 380,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'THE TRUTH',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          card.answer,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Icon(
                          Icons.visibility_off_outlined,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to flip back',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (!_isFlipped)
              ElevatedButton.icon(
                onPressed: () {
                  _cardKey.currentState?.toggleCard();
                  setState(() {
                    _isFlipped = true;
                  });
                },
                icon: const Icon(Icons.visibility),
                label: const Text('SHOW ANSWER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                ),
              )
            else
              Row(
                children: [
                  _buildSRSButton(
                    label: 'Again',
                    subtitle: '1d',
                    color: Colors.red,
                    bgColor: theme.brightness == Brightness.dark ? const Color(0xFF451A1A) : Colors.red[50]!,
                    onTap: () => _nextCard(1),
                  ),
                  const SizedBox(width: 8),
                  _buildSRSButton(
                    label: 'Hard',
                    subtitle: _formatInterval(_estimateNextInterval(card, 3)),
                    color: Colors.orange,
                    bgColor: theme.brightness == Brightness.dark ? const Color(0xFF452C1A) : Colors.orange[50]!,
                    onTap: () => _nextCard(3),
                  ),
                  const SizedBox(width: 8),
                  _buildSRSButton(
                    label: 'Good',
                    subtitle: _formatInterval(_estimateNextInterval(card, 4)),
                    color: Colors.blue,
                    bgColor: theme.brightness == Brightness.dark ? const Color(0xFF1E2E4A) : Colors.blue[50]!,
                    onTap: () => _nextCard(4),
                  ),
                  const SizedBox(width: 8),
                  _buildSRSButton(
                    label: 'Easy',
                    subtitle: _formatInterval(_estimateNextInterval(card, 5)),
                    color: Colors.green,
                    bgColor: theme.brightness == Brightness.dark ? const Color(0xFF1A4523) : Colors.green[50]!,
                    onTap: () => _nextCard(5),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ChatOverlay extends StatefulWidget {
  final Flashcard card;
  const _ChatOverlay({required this.card});
  @override
  State<_ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends State<_ChatOverlay> {
  final _messages = <Map<String, String>>[];
  final _controller = TextEditingController();
  final _aiService = AIService();
  bool _isLoading = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final contextText = 'Question: ${widget.card.question}\nAnswer: ${widget.card.answer}';
      final reply = await _aiService.chatWithAssistant(text, contextText);
      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'content': reply});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'content': 'Error communicating with AI: $e'});
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24, left: 24, right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('AI Study Assistant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser 
                          ? Theme.of(context).colorScheme.primary 
                          : (Theme.of(context).brightness == Brightness.dark 
                              ? const Color(0xFF334155) 
                              : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                        bottomLeft: !isUser ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(
                        color: isUser 
                            ? Colors.white 
                            : (Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator())),
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask about this card...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
