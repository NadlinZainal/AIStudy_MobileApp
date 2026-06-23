import 'dart:io';

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/social_provider.dart';
import 'flashcard_list_screen.dart';
import '../utils/neumorphic_widgets.dart';

// Shared gradient palette — one source of truth for both the card icon and
// any future uses (e.g. a hero animation background).
const _kDeckGradients = [
  LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  LinearGradient(colors: [Color(0xFFF7971E), Color(0xFFFFD200)], begin: Alignment.topLeft, end: Alignment.bottomRight),
];

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : const Color(0xFFF5F0FF),
      body: SafeArea(
        child: Consumer<DeckProvider>(
          builder: (context, deckProvider, _) {
            final decks = deckProvider.decks;
            
            final filteredDecks = decks.where((deck) {
              final query = _searchQuery.toLowerCase();
              return deck.title.toLowerCase().contains(query) ||
                  deck.description.toLowerCase().contains(query);
            }).toList();

            return CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      children: [
                        Text(
                          'Deck Library',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Browse your decks and jump into a focused review session.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── Search Bar ───────────────────────────────────────────
                if (decks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search decks...',
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
                  ),

                // ── Body ──────────────────────────────────────────────────
                if (deckProvider.isLoading)
                  const SliverFillRemaining(
                    child: Center(child: NeumorphicLoader(label: 'Loading your decks…')),
                  )
                else if (decks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: NeumorphicEmptyState(
                          icon: Icons.style_outlined,
                          title: 'Create your first deck',
                          subtitle: 'Add a deck to begin building your study routine.',
                        ),
                      ),
                    ),
                  )
                else if (filteredDecks.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: NeumorphicEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matches found',
                          subtitle: 'Try searching for a different keyword or deck title.',
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                    sliver: SliverList.separated(
                      itemCount: filteredDecks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _DeckCard(
                        deck: filteredDecks[index],
                        gradient: _kDeckGradients[index % _kDeckGradients.length],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: () => _showAddDeckDialog(context, context.read<DeckProvider>()),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  void _showAddDeckDialog(BuildContext context, DeckProvider provider) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => _DeckFormDialog(
        title: 'Create new deck',
        confirmLabel: 'Create',
        titleController: titleController,
        descController: descController,
        onConfirm: () async {
          if (titleController.text.isNotEmpty) {
            await provider.addDeck(titleController.text, descController.text);
            if (context.mounted) Navigator.pop(context);
          }
        },
      ),
    );
  }
}

// ─── Deck Card ───────────────────────────────────────────────────────────────

class _DeckCard extends StatelessWidget {
  final Deck deck;
  final LinearGradient gradient;

  const _DeckCard({required this.deck, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FlashcardListScreen(deck: deck)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gradient icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.style_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),

            // Info + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deck.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FutureBuilder<int>(
                        future: context.read<DeckProvider>().getDueCount(deck.id),
                        builder: (context, snapshot) {
                          final dueCount = snapshot.data ?? 0;
                          if (dueCount == 0) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark 
                                  ? const Color(0xFF451A1A) 
                                  : Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.brightness == Brightness.dark 
                                    ? const Color(0xFFB91C1C) 
                                    : Colors.red[200]!,
                              ),
                            ),
                            child: Text(
                              '$dueCount due',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark 
                                    ? Colors.red[300] 
                                    : Colors.red[700],
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    deck.description.isEmpty ? 'View flashcards' : deck.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<double>(
                    future: context.read<DeckProvider>().getDeckProgress(deck.id),
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor:
                                  theme.colorScheme.primary.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Favorite Toggle
            IconButton(
              icon: Icon(
                deck.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: deck.isFavorite
                    ? Colors.redAccent
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                size: 22,
              ),
              onPressed: () {
                context.read<DeckProvider>().toggleDeckFavorite(deck);
              },
            ),

            // Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) => _handleMenuAction(context, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'share', child: Text('Share')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── All action methods below are unchanged ───────────────────────────────

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':   _showEditDeckDialog(context, deck);
      case 'share':  _shareDeck(context, deck);
      case 'delete': _confirmDeleteDeck(context, deck);
    }
  }

  void _showEditDeckDialog(BuildContext context, Deck deck) {
    final titleController = TextEditingController(text: deck.title);
    final descController = TextEditingController(text: deck.description);
    showDialog(
      context: context,
      builder: (_) => _DeckFormDialog(
        title: 'Edit deck',
        confirmLabel: 'Save',
        titleController: titleController,
        descController: descController,
        onConfirm: () async {
          if (titleController.text.isNotEmpty) {
            final updatedDeck = Deck(
              id: deck.id,
              userId: deck.userId,
              title: titleController.text,
              description: descController.text,
              createdAt: deck.createdAt,
              isFavorite: deck.isFavorite,
            );
            await context.read<DeckProvider>().updateDeck(updatedDeck);
            if (context.mounted) Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _confirmDeleteDeck(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete deck?'),
        content: Text(
          'Delete "${deck.title}" and all its flashcards? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<DeckProvider>().deleteDeck(deck.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _shareDeck(BuildContext context, Deck deck) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Share deck',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('Share with a friend'),
                subtitle: const Text('Send this deck over DM'),
                onTap: () {
                  Navigator.pop(context);
                  _showShareWithFriendDialog(context, deck);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Export as PDF'),
                subtitle: const Text('Save and share a deck summary'),
                onTap: () {
                  Navigator.pop(context);
                  _exportDeckToPdf(context, deck);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Share via link'),
                subtitle: const Text('Create a shareable deck link'),
                onTap: () {
                  Navigator.pop(context);
                  _shareDeckLink(context, deck);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareWithFriendDialog(BuildContext context, Deck deck) {
    final socialProvider = context.read<SocialProvider?>();
    if (socialProvider == null || socialProvider.friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No friends to share with. Add some first!')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Share with Friend'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: socialProvider.friends.length,
            itemBuilder: (context, index) {
              final friend = socialProvider.friends[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    friend.username.isNotEmpty
                        ? friend.username[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(friend.name),
                subtitle: Text('@${friend.username}'),
                onTap: () async {
                  await socialProvider.shareDeck(friend.id, deck.id, deck.title);
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Shared deck with ${friend.name}!')),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _exportDeckToPdf(BuildContext context, Deck deck) async {
    final flashcards = await context.read<DeckProvider>().getFlashcardsForDeck(deck.id);
    final pdf = PdfDocument();
    PdfPage page = pdf.pages.add();
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    double y = 0;
    page.graphics.drawString(deck.title, titleFont, bounds: const Rect.fromLTWH(0, 0, 500, 40));
    y += 48;
    final descEl = PdfTextElement(
      text: deck.description.isNotEmpty ? deck.description : 'No description provided.',
      font: bodyFont,
    );
    final descLayout = descEl.draw(page: page, bounds: Rect.fromLTWH(0, y, 500, 120))!;
    y = descLayout.bounds.bottom + 16;
    page.graphics.drawString('Flashcards', labelFont, bounds: Rect.fromLTWH(0, y, 500, 20));
    y += 28;
    if (flashcards.isEmpty) {
      page.graphics.drawString('No flashcards found for this deck.', bodyFont, bounds: Rect.fromLTWH(0, y, 500, 20));
      y += 24;
    } else {
      for (var card in flashcards) {
        final qEl = PdfTextElement(text: 'Q: ${card.question}', font: bodyFont);
        final qLayout = qEl.draw(page: page, bounds: Rect.fromLTWH(0, y, 500, 80))!;
        y = qLayout.bounds.bottom + 6;
        final aEl = PdfTextElement(text: 'A: ${card.answer}', font: bodyFont);
        final aLayout = aEl.draw(page: page, bounds: Rect.fromLTWH(0, y, 500, 80))!;
        y = aLayout.bounds.bottom + 18;
        if (y > page.getClientSize().height - 80) {
          page = pdf.pages.add();
          y = 0;
        }
      }
    }
    page.graphics.drawString(
      'Deck ID: ${deck.id}',
      PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.italic),
      bounds: Rect.fromLTWH(0, page.getClientSize().height - 30, 500, 20),
    );
    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = renderBox != null
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : Rect.fromLTWH(0, 0, 1, 1);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final List<int> bytes = await pdf.save();
    pdf.dispose();
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${deck.title.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}_deck.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Here is the deck summary for "${deck.title}".',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Could not export PDF: $e')));
    }
  }

  void _shareDeckLink(BuildContext context, Deck deck) {
    final shareLink = 'https://aistudy.app/share/deck/${deck.id}';
    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = renderBox != null
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : Rect.fromLTWH(0, 0, 1, 1);
    Share.share(
      'Check out this deck: ${deck.title}\n$shareLink',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}

// ─── Shared Form Dialog ───────────────────────────────────────────────────────

class _DeckFormDialog extends StatelessWidget {
  final String title;
  final String confirmLabel;
  final TextEditingController titleController;
  final TextEditingController descController;
  final VoidCallback onConfirm;

  const _DeckFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.titleController,
    required this.descController,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Deck title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descController,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}