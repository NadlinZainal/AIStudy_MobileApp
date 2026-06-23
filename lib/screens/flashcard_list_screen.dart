import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/social_provider.dart';
import '../widgets/chat_action_button.dart';
import 'quiz_screen.dart';
import 'study_screen.dart';
import 'quiz_history_screen.dart';
import '../utils/custom_snackbar.dart';
import '../services/ai_service.dart';
import '../services/file_service.dart';

class FlashcardListScreen extends StatefulWidget {
  final Deck deck;

  const FlashcardListScreen({super.key, required this.deck});

  @override
  State<FlashcardListScreen> createState() => _FlashcardListScreenState();
}

class _FlashcardListScreenState extends State<FlashcardListScreen> {
  late Future<List<Flashcard>> _flashcardsFuture;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  void _loadFlashcards() {
    setState(() {
      _flashcardsFuture =
          context.read<DeckProvider>().getFlashcardsForDeck(widget.deck.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.deck.title),
            if (widget.deck.description.isNotEmpty)
              Text(
                widget.deck.description,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey),
              ),
          ],
        ),
        actions: [
             ActionIconButton(
               icon: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
               onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizHistoryScreen(deck: widget.deck),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.school, color: Theme.of(context).colorScheme.primary),
            tooltip: 'Study Mode',
            onPressed: () async {
              final cards = await _flashcardsFuture;
              if (cards.isEmpty) {
                if (context.mounted) {
                  CustomSnackBar.show(
                    context,
                    message: 'Add some flashcards first!',
                    type: SnackBarType.error,
                  );
                }
                return;
              }
              if (context.mounted) {
                _startStudyOrQuiz(cards, isQuiz: false);
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Flashcard>>(
        future: _flashcardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No flashcards yet. Be the first to add one!'),
                ],
              ),
            );
          }

          final cards = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _startStudyOrQuiz(cards, isQuiz: true);
                      },
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('START QUIZ SESSION'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 600,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent:
                        130, // Appropriate height for flashcard list items
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final theme = Theme.of(context);
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  card.question,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              _buildDueBadge(context, card.nextReviewDate),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              card.answer,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ) ??
                                  TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 13),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditFlashcardDialog(card);
                              }
                              if (value == 'share') {
                                _showShareDialog(card);
                              }
                              if (value == 'delete') {
                                _deleteFlashcard(card.id);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(
                                  value: 'share',
                                  child: Text('Share with Friend')),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showShareDialog(Flashcard card) {
    final socialProvider = context.read<SocialProvider?>();
    if (socialProvider == null || socialProvider.friends.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'No friends to share with. Add some first!',
        type: SnackBarType.info,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share with Friend'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: socialProvider.friends.length,
            itemBuilder: (context, index) {
              final friend = socialProvider.friends[index];
              return ListTile(
                leading:
                    CircleAvatar(child: Text(friend.username[0].toUpperCase())),
                title: Text(friend.name),
                subtitle: Text('@${friend.username}'),
                onTap: () {
                  socialProvider.shareFlashcard(friend.id, card);
                  Navigator.pop(context);
                  CustomSnackBar.show(
                    context,
                    message: 'Shared with ${friend.name}!',
                    type: SnackBarType.success,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showAddFlashcardDialog() {
    final questionController = TextEditingController();
    final answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Flashcard'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: InputDecoration(
                labelText: 'Question',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: answerController,
              decoration: InputDecoration(
                labelText: 'Answer',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (questionController.text.isNotEmpty &&
                  answerController.text.isNotEmpty) {
                context.read<DeckProvider>().addFlashcard(
                      widget.deck.id,
                      questionController.text,
                      answerController.text,
                    );
                Navigator.pop(context);
                _loadFlashcards();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditFlashcardDialog(Flashcard card) {
    final questionController = TextEditingController(text: card.question);
    final answerController = TextEditingController(text: card.answer);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Flashcard'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: InputDecoration(
                labelText: 'Question',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: answerController,
              decoration: InputDecoration(
                labelText: 'Answer',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (questionController.text.isNotEmpty &&
                  answerController.text.isNotEmpty) {
                final updatedCard = Flashcard(
                  id: card.id,
                  userId: card.userId,
                  deckId: card.deckId,
                  question: questionController.text,
                  answer: answerController.text,
                  createdAt: card.createdAt,
                );
                context.read<DeckProvider>().updateFlashcard(updatedCard);
                Navigator.pop(context);
                _loadFlashcards();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteFlashcard(String id) {
    context.read<DeckProvider>().deleteFlashcard(id);
    _loadFlashcards();
  }

  void _startStudyOrQuiz(List<Flashcard> allCards, {required bool isQuiz}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dueCards = allCards.where((c) => c.nextReviewDate <= now).toList();
    
    if (dueCards.isEmpty) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Icon(Icons.check_circle_outline, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'All caught up! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No cards are currently due for review in this deck. Would you like to review all cards anyway?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToSession(allCards, isQuiz: isQuiz);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Custom Review (All Cards)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Review Selection',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have ${dueCards.length} cards due for review in this deck.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToSession(dueCards, isQuiz: isQuiz);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Review Due Cards (${dueCards.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToSession(allCards, isQuiz: isQuiz);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  child: Text('Review All Cards (${allCards.length})', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _navigateToSession(List<Flashcard> cards, {required bool isQuiz}) {
    if (isQuiz) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(deck: widget.deck, flashcards: cards),
        ),
      ).then((_) => _loadFlashcards());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudyScreen(deck: widget.deck, flashcards: cards),
        ),
      ).then((_) => _loadFlashcards());
    }
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Add Flashcards',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: const Text('Add Manually'),
                  subtitle: const Text('Type your own question and answer'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddFlashcardDialog();
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.green),
                  ),
                  title: const Text('Scan with Camera (AI)'),
                  subtitle: const Text('Take a picture of notes or textbook pages'),
                  onTap: () {
                    Navigator.pop(context);
                    _processOcrGeneration(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    child: const Icon(Icons.image_outlined, color: Colors.purple),
                  ),
                  title: const Text('Upload Image (AI)'),
                  subtitle: const Text('Choose an existing image or document scan'),
                  onTap: () {
                    Navigator.pop(context);
                    _processOcrGeneration(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processOcrGeneration(ImageSource source) async {
    final fileService = FileService();
    final aiService = AIService();
    
    String? extractedText;
    
    // 1. Pick and OCR Image
    try {
      extractedText = await fileService.extractTextFromImage(source);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Failed to extract text: $e',
          type: SnackBarType.error,
        );
      }
      return;
    }
    
    if (extractedText == null) {
      // User cancelled image picking
      return;
    }
    
    if (extractedText.isEmpty) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'No text was found in the image. Please try a clearer image.',
          type: SnackBarType.info,
        );
      }
      return;
    }
    
    // 2. Show loading spinner dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'AI Study Coach is reading your material...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Analyzing text and generating flashcards.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    
    // 3. Generate flashcards
    List<Map<String, String>> generatedCards = [];
    String? errorMsg;
    try {
      generatedCards = await aiService.generateFlashcards(extractedText);
    } catch (e) {
      errorMsg = e.toString();
    }
    
    // Pop the loading dialog
    if (mounted) {
      Navigator.pop(context);
    }
    
    if (errorMsg != null) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'AI Generation failed: $errorMsg',
          type: SnackBarType.error,
        );
      }
      return;
    }
    
    if (generatedCards.isEmpty) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'AI failed to generate any cards from the material.',
          type: SnackBarType.info,
        );
      }
      return;
    }
    
    // 4. Show review dialog
    if (mounted) {
      _showOcrReviewDialog(generatedCards);
    }
  }

  void _showOcrReviewDialog(List<Map<String, String>> generatedCards) {
    List<bool> selected = List.generate(generatedCards.length, (index) => true);
    List<Map<String, String>> cardsCopy = List.from(generatedCards.map((c) => Map<String, String>.from(c)));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  const Text('Review AI Flashcards'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'AI generated ${generatedCards.length} flashcards. Select which ones to keep:',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: cardsCopy.length,
                        itemBuilder: (context, index) {
                          final card = cardsCopy[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: selected[index] 
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                            color: Theme.of(context).cardColor,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: CheckboxListTile(
                                activeColor: Theme.of(context).colorScheme.primary,
                                value: selected[index],
                                onChanged: (val) {
                                  setDialogState(() {
                                    selected[index] = val ?? false;
                                  });
                                },
                                title: Text(
                                  card['question'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    card['answer'] ?? '',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                secondary: IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () async {
                                    final edited = await _showEditSingleCardDialog(
                                      card['question'] ?? '',
                                      card['answer'] ?? '',
                                    );
                                    if (edited != null) {
                                      setDialogState(() {
                                        cardsCopy[index] = edited;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Discard All', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final List<Map<String, String>> cardsToAdd = [];
                    for (int i = 0; i < cardsCopy.length; i++) {
                      if (selected[i]) {
                        cardsToAdd.add(cardsCopy[i]);
                      }
                    }

                    if (cardsToAdd.isEmpty) {
                      CustomSnackBar.show(
                        context,
                        message: 'No flashcards selected.',
                        type: SnackBarType.info,
                      );
                      return;
                    }

                    final navigator = Navigator.of(context);
                    final deckProvider = context.read<DeckProvider>();

                    await deckProvider.addMultipleFlashcards(
                          widget.deck.id,
                          cardsToAdd,
                        );

                    navigator.pop();
                    _loadFlashcards();
                    
                    if (context.mounted) {
                      CustomSnackBar.show(
                        context,
                        message: 'Successfully added ${cardsToAdd.length} flashcards!',
                        type: SnackBarType.success,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add to Deck'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>?> _showEditSingleCardDialog(String question, String answer) {
    final qController = TextEditingController(text: question);
    final aController = TextEditingController(text: answer);
    
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Card Details'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qController,
              decoration: InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: aController,
              decoration: InputDecoration(
                labelText: 'Answer',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'question': qController.text,
                'answer': aController.text,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDueBadge(BuildContext context, int nextReviewDate) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (nextReviewDate == 0) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E3A2F) : Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF065F46) : Colors.green[200]!,
          ),
        ),
        child: Text(
          'NEW',
          style: TextStyle(
            color: isDark ? Colors.green[300] : Colors.green[700],
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final now = DateTime.now();
    final dueDate = DateTime.fromMillisecondsSinceEpoch(nextReviewDate);
    final difference = dueDate.difference(now);

    String text;
    Color? bgColor;
    Color? borderColor;
    Color? textColor;

    if (difference.isNegative) {
      if (difference.inDays.abs() == 0) {
        text = 'DUE';
      } else if (difference.inDays.abs() == 1) {
        text = 'DUE (1d late)';
      } else {
        text = 'DUE (${difference.inDays.abs()}d late)';
      }
      bgColor = isDark ? const Color(0xFF451A1A) : Colors.red[50];
      borderColor = isDark ? const Color(0xFFB91C1C) : Colors.red[200]!;
      textColor = isDark ? Colors.red[300] : Colors.red[700];
    } else {
      if (difference.inDays == 0) {
        if (difference.inHours > 0) {
          text = 'IN ${difference.inHours}H';
        } else {
          text = 'IN ${difference.inMinutes}M';
        }
        bgColor = isDark ? const Color(0xFF3E2D1A) : Colors.orange[50];
        borderColor = isDark ? const Color(0xFFD97706) : Colors.orange[200]!;
        textColor = isDark ? Colors.orange[300] : Colors.orange[700];
      } else if (difference.inDays == 1) {
        text = 'TOMORROW';
        bgColor = isDark ? const Color(0xFF1E293B) : Colors.blue[50];
        borderColor = isDark ? const Color(0xFF475569) : Colors.blue[200]!;
        textColor = isDark ? Colors.blue[300] : Colors.blue[700];
      } else {
        text = 'IN ${difference.inDays}D';
        bgColor = isDark ? const Color(0xFF2E1A47) : Colors.purple[50];
        borderColor = isDark ? const Color(0xFF7C3AED) : Colors.purple[200]!;
        textColor = isDark ? Colors.purple[300] : Colors.purple[700];
      }
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
