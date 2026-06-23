import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../providers/social_provider.dart';
import '../models/deck.dart';
import 'flashcard_list_screen.dart';
import 'quiz_screen.dart';
import 'study_screen.dart';
import 'notifications_screen.dart';
import '../utils/custom_snackbar.dart';
import '../utils/neumorphic_widgets.dart';

const _kDeckGradients = [
  LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  LinearGradient(colors: [Color(0xFFF7971E), Color(0xFFFFD200)], begin: Alignment.topLeft, end: Alignment.bottomRight),
];

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeckProvider>().loadDecks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(BuildContext context, DeckProvider provider, Deck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from Favourites?'),
        content: Text('Are you sure you want to remove "${deck.title}" from favourites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.toggleDeckFavorite(deck);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startStudy(Deck deck, DeckProvider provider) async {
    final cards = await provider.getFlashcardsForDeck(deck.id);
    if (!mounted) return;
    if (cards.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Add some flashcards to this deck first!',
        type: SnackBarType.error,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyScreen(deck: deck, flashcards: cards),
      ),
    ).then((_) => provider.loadDecks());
  }

  Future<void> _startQuiz(Deck deck, DeckProvider provider) async {
    final cards = await provider.getFlashcardsForDeck(deck.id);
    if (!mounted) return;
    if (cards.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Add some flashcards to this deck first!',
        type: SnackBarType.error,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(deck: deck, flashcards: cards),
      ),
    ).then((_) => provider.loadDecks());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Decks', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<SocialProvider?>(
            builder: (context, social, child) {
              final count = social?.totalNotificationCount ?? 0;
              return IconButton(
                icon: Badge(
                  label: Text(count.toString()),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DeckProvider>(
        builder: (context, deckProvider, child) {
          if (deckProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final favoriteDecks = deckProvider.decks.where((deck) => deck.isFavorite).toList();

          if (favoriteDecks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: NeumorphicEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No favorite decks yet',
                  subtitle: 'Heart a deck to add it here!',
                ),
              ),
            );
          }

          final filteredDecks = favoriteDecks.where((deck) {
            final query = _searchQuery.toLowerCase();
            return deck.title.toLowerCase().contains(query) ||
                deck.description.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search favorite decks...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),

              // Filtered list
              Expanded(
                child: filteredDecks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: NeumorphicEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches found',
                            subtitle: 'Try searching for a different keyword or deck title.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 4, bottom: 100),
                        itemCount: filteredDecks.length,
                        itemBuilder: (context, index) {
                          final deck = filteredDecks[index];
                          final gradientColors = _kDeckGradients[index % _kDeckGradients.length].colors;

                          return _AnimatedFavoriteCard(
                            index: index,
                            child: FutureBuilder<DeckStats>(
                              future: deckProvider.getDeckStats(deck.id),
                              builder: (context, snapshot) {
                                final stats = snapshot.data ??
                                    DeckStats(
                                      totalCount: 0,
                                      masteredCount: 0,
                                      dueCount: 0,
                                      progress: 0.0,
                                    );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        gradientColors[0].withValues(alpha: isDark ? 0.25 : 0.9),
                                        gradientColors[1].withValues(alpha: isDark ? 0.15 : 0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradientColors[1].withValues(alpha: isDark ? 0.15 : 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(24),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => FlashcardListScreen(deck: deck),
                                              ),
                                            ).then((_) => deckProvider.loadDecks());
                                          },
                                          onLongPress: () => _showDeleteDialog(context, deckProvider, deck),
                                          child: Padding(
                                            padding: const EdgeInsets.all(22.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Header Row: Icon, Title, and heart toggle, popup menu
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(16),
                                                      ),
                                                      child: const Icon(Icons.style, color: Colors.white, size: 24),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            deck.title,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 18,
                                                              color: Colors.white,
                                                              letterSpacing: 0.3,
                                                            ),
                                                          ),
                                                          if (deck.description.isNotEmpty) ...[
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              deck.description,
                                                              style: TextStyle(
                                                                color: Colors.white.withValues(alpha: 0.85),
                                                                fontSize: 13,
                                                              ),
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    // Favorite toggle icon
                                                    IconButton(
                                                      icon: const Icon(Icons.favorite, color: Colors.white),
                                                      onPressed: () {
                                                        deckProvider.toggleDeckFavorite(deck);
                                                      },
                                                    ),
                                                    // More options popup menu
                                                    PopupMenuButton<String>(
                                                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                                                      onSelected: (value) {
                                                        if (value == 'delete') {
                                                          _showDeleteDialog(context, deckProvider, deck);
                                                        }
                                                      },
                                                      itemBuilder: (context) => [
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                              SizedBox(width: 8),
                                                              Text('Delete Deck', style: TextStyle(color: Colors.red)),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 18),
                                                
                                                // Stats Badges Row: Card count & Due Count
                                                Row(
                                                  children: [
                                                    // Card Count Chip
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.18),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.layers_outlined, color: Colors.white, size: 14),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '${stats.totalCount} cards',
                                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (stats.dueCount > 0) ...[
                                                      const SizedBox(width: 8),
                                                      // Due Count Chip
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: Colors.redAccent.withValues(alpha: 0.3),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.bolt, color: Colors.white, size: 14),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '${stats.dueCount} due',
                                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 18),

                                                // Progress bar section
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Mastery Progress',
                                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                                                        ),
                                                        Text(
                                                          '${(stats.progress * 100).toStringAsFixed(0)}%',
                                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        value: stats.progress,
                                                        minHeight: 6,
                                                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 20),

                                                // Dual Action Buttons: Study & Quiz
                                                Row(
                                                  children: [
                                                    // Quick Study Button
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => _startStudy(deck, deckProvider),
                                                        icon: const Icon(Icons.menu_book_rounded, size: 16, color: Colors.white),
                                                        label: const Text(
                                                          'Quick Study',
                                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    // Quick Quiz Button
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () => _startQuiz(deck, deckProvider),
                                                        icon: Icon(Icons.auto_awesome_rounded, size: 16, color: gradientColors[1]),
                                                        label: Text(
                                                          'Quick Quiz',
                                                          style: TextStyle(color: gradientColors[1], fontSize: 12, fontWeight: FontWeight.bold),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          elevation: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedFavoriteCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedFavoriteCard({
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedFavoriteCard> createState() => _AnimatedFavoriteCardState();
}

class _AnimatedFavoriteCardState extends State<_AnimatedFavoriteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
